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

my $basedir = "/var/ksp";
my $gpg = "/usr/bin/gpg";
my $gpgflags = "-q --no-options --homedir=$basedir/gpg";

my $daemonize = 1;
my $debug = 0;

# Fire up a HTTP listener to deal with requests.
my $d = HTTP::Daemon->new(
    LocalAddr => "0.0.0.0",
    LocalPort => 11371,
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

	print STDERR "$m\n" if $debug;
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
		if ($keyid eq "" or $uid eq "") {
			send_response($c, 400, "Invalid key");
			last;
		}

		# Don't accept keys after the submission deadline.
		if (-e "$basedir/kspd.lock") {
			send_response($c, 403, "Submissions closed");
			last;
		}

		my $keyfile = "$basedir/keys/$keyid";
		unlink $keyfile if -e $keyfile;
		if (!link $f, $keyfile) {
			send_response($c, 500, "Write error");
			last;
		}
		chmod 0644, $keyfile;

		send_response($c, 200, "Key submitted");
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
while (my $c = $d->accept) {
	my $peer = $c->peerhost();

	while (my $r = $c->get_request) {
		if ($r->method eq "POST" and $r->url->path eq "/pks/add") {
			add_key($c, $r);
		} else {
			send_response($c, 501, "Not implemented");
		}
	}

	$c->close;
	undef($c);
}
