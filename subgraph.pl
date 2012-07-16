#!/usr/bin/perl -w

# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <philip@fosdem.org> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return.      - Philip Paeps
# ----------------------------------------------------------------------------

#
# Generates a graph of submissions per day from the mtimes of the keys.
# This could be done much simpler, but it would be even scarier to read.
#

use strict;
use DirHandle;
use POSIX qw/strftime/;
use RRDs;
use Time::Local;

my $year = "2012";			# Current FOSDEM edition.
my $startdate = "20111217";		# Start date of submissions.
my $basedir = "/var/ksp";		# Absolute location of files.

# Bail out if submissions are closed!
if (-e "$basedir/kspd.lock") {
	exit 0;
}

# Get timestamps for all files in the given directory.
sub getmtimes($) {
	my $dir = shift;
	my $d = DirHandle->new($dir);
	return	map  { $_ => (stat($_))[9]}
		map  { "$dir/$_" }
		grep { ! m/^\.|\!/ }
		$d->read();
}

# Create the rrdtool database.
sub createrrd() {
	unlink "$basedir/keys.rrd";
	RRDs::create("$basedir/keys.rrd", "--start", $startdate,
	    "--step", "1days", "DS:keys:GAUGE:86400:0:U",
	    "RRA:MAX:0.5:86400:365");
	my $err = RRDs::error;
	if ($err) {
		warn "Error creating RRD: $err\n";
	}
}

# Create the rrdtool graph.
sub creategraph() {
	RRDs::graph("$basedir/graphs/submissions.png", "--start", $startdate,
	    "-w", 512, "-t", "Key Submissions per Day ($year)", "-v",
	    "# of keys", "DEF:keys=$basedir/keys.rrd:keys:MAX",
	    "LINE:keys#ff0000:Keys submitted");
	my $err = RRDs::error;
	if ($err) {
		warn "Error creating graph: $err\n";
	}
}

# Create a fresh rrdtool database.
createrrd();

# Get the number of submissions per day.
my %days = ();
my %mtimes = getmtimes("$basedir/keys");
foreach my $keys (sort{$mtimes{$a} <=> $mtimes{$b}} keys %mtimes) {
	$days{strftime("%Y-%m-%d", localtime($mtimes{$keys}))}++;
}

# Let rrdtool have them.
foreach my $day (sort(keys %days)) {
	my ($y, $m, $d) = split(/-/, $day);
	my $time = timelocal(0, 0, 0, $d, $m-1, $y-1900);
	my $err;

	#printf "$day - $days{$day}\n";
	RRDs::update("$basedir/keys.rrd", "$time:$days{$day}");
	$err = RRDs::error;
	if ($err) {
		warn "Error updating RRD: $err\n";
	}
}

# Graph the results.
creategraph();
