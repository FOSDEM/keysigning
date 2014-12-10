#!/usr/bin/perl -w

# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <philip@fosdem.org> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return.      - Philip Paeps
# ----------------------------------------------------------------------------

#
# Hackish implementation of draft-shaw-openpgp-hkp-00.txt.
# Loosely based on a similar hack by Alexander Wirt (formorer).
#

use strict;

use CGI::Util qw/unescape/;
use File::Temp qw/tempfile/;
use HTTP::Daemon;
use POSIX;

my $basedir = "/var/ksp";
my $gpg = "/usr/bin/gpg";
my $gpgflags = "-q --no-options --homedir=$basedir/gpg";

my $daemonize = 1;
my $debug = 0;

my %kspd = (
	LocalAddr => "ksp.fosdem.org",
	LocalPort => 11371,
	PreFork => 5,
	MaxReq => 10,
	Timeout => 30,
);
my %children = ();

# Fire up a HTTP listener to deal with requests.
my $d = HTTP::Daemon->new(
    LocalAddr => $kspd{LocalAddr},
    LocalPort => $kspd{LocalPort},
    Reuse	=> 1,
    ) or die "Couldn't create HTTP::Daemon instance: $!";

#
# Wrapper around $c->send_response().
#
sub send_response($$$) {
	my ($c, $s, $m) = @_;

	my $response = HTTP::Response->new($s);
	$response->content($m);
	$response->header("Content-Type" => "text/plain");
	$c->send_response($response);
	$c->send_crlf;
}

#
# Naive validation of POSTed data.
#
sub decode_key($) {
	my $r = shift;
	my $content =  $r->decoded_content;

	# Error out if it doesn't look a bit like a key.
	return unless ($content =~ m/keytext=(.*)$/ );

	my ($fh, $filename) = tempfile("kspd.XXXXXX");
	print $fh unescape("$1");
	return $filename;
}

#
# Store the key.
#
sub add_key($$) {
	my ($c, $r) = @_;
	my $f = decode_key($r);

	if (!$f) {
	    print STDERR "Key rejected: invalid data\n" if $debug;
	    send_response($c, 400, "Invalid data");
	    return;
	}

	open (GPG, '-|', "$gpg $gpgflags --with-colons $f")
	    or send_response($c, 500, "Internal error");

	while (<GPG>) {
		next unless /^pub:/;

		my ($type, $trust, $keylength, $algorithm, $keyid,
		    $creationdate, $expirationdate, $serial, $ownertrust,
		    $uid, $rest) = split(/:/, $_);

		# Sanity check.
		if ($keyid eq "" or $uid eq "" or $keylength == 0) {
			print STDERR "Key rejected: invalid key\n" if $debug;
			send_response($c, 400, "Invalid key");
			last;
		}

		# Don't accept keys after the submission deadline.
		if (-e "$basedir/kspd.lock") {
			print STDERR "Key rejected: kspd locked\n" if $debug;
			$c->force_last_request;
			send_response($c, 403, "Submissions closed");
			last;
		}

		my $keyfile = "$basedir/keys/$keyid";
		unlink $keyfile if -e $keyfile;
		if (!link $f, $keyfile) {
			print STDERR "Key rejected: $!\n" if $debug;
			$c->force_last_request;
			send_response($c, 500, "Write error");
			last;
		}
		chmod 0644, $keyfile;

		print STDERR "Key accepted: $keyid ($uid)\n" if $debug;
		send_response($c, 200, "$keyid successfully submitted");
		last;
	}

	close(GPG);
	unlink $f;
	return;
}

#
# Fork into the background.
#
if ($daemonize) {
	open STDIN, '/dev/null'   or die "Can't read /dev/null: $!";
	open STDERR, '>/dev/null' or die "Can't write to /dev/null: $!";
	open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
	defined(my $pid = fork)   or die "Can't fork: $!";
	if ($pid) { exit if $pid; }
}

#
# Accept HTTP::Daemon connections and dispatch them to do stuff.
#
sub handle_connection($) {
	my $c = shift;

	printf STDERR "Connection from %s\n", $c->peerhost if $debug;

	$c->timeout($kspd{'Timeout'});
	while (my $r = $c->get_request) {
		if ($r->method eq "POST" and $r->url->path eq "/pks/add") {
			add_key($c, $r);
		} else {
			printf STDERR "Invalid request: %s %s\n",
			    $r->method, $r->url->path if $debug;
			$c->force_last_request;
			send_response($c, 501,
			    "This keyserver only accepts submissions");
		}
	}
	$c->close;

	printf STDERR "Connection closed: %s\n", $c->reason if $debug;
	undef($c);
}

#
# Create a new child process to handle connections.
#
sub new_child() {
	my $pid;
	my $sigset;

	$sigset = POSIX::SigSet->new(SIGINT);
	sigprocmask(SIG_BLOCK, $sigset)
		or die "Can't block SIGINT for fork: $!\n";
	die "Couldn't fork: $!" unless defined ($pid = fork);

	if ($pid) {
		# Parent: record childbirth and return.
		sigprocmask(SIG_UNBLOCK, $sigset)
			or die "Can't unblock SIGINT for parent: $!\n";
		$children{$pid} = 1;
		return;
	} else {
		# Child: does not return.
		$SIG{INT} = 'DEFAULT';
		sigprocmask(SIG_UNBLOCK, $sigset)
			or die "Can't unblock SIGINT for child: $!\n";
		for (my $i = 0; $i < $kspd{MaxReq}; $i++) {
			my $c = $d->accept or last;
			handle_connection($c);
		}
		# Prevent proliferation of zombies.
		exit;
	}
}

sub REAPER {				# Takes care of dead children.
	$SIG{CHLD} = \&REAPER;
	my $pid = wait;
	delete $children{$pid};
}

sub HUNTSMAN {				# Signal handler for SIGINT.
	local($SIG{CHLD}) = 'IGNORE';	# We're going to kill our children.
	kill 'INT' => keys %children;
	exit;				# Clean up with dignity.
}

# Prefork children.
for (1 .. $kspd{PreFork}) {
	new_child();
}

# Install signal handlers.
$SIG{CHLD} = \&REAPER;
$SIG{INT}  = \&HUNTSMAN;

# And maintain the population.
while (1) {
	sleep;			# Wait for a signal (e.g., child's death).
	for (scalar(keys %children) .. $kspd{PreFork}-1) {
		new_child();	# Top up the child pool.
	}
}
