#!/usr/bin/perl

# Very quick hack to re-sort the keylist.txt file by name
# This allows you to see if multiple keys of the same participant are not
# sorted together, so you can manually `touch` the files to fix it

use strict;
use warnings;

my $state = "init";
my ($num,$keyid,$uid);
while(<>) {
	if( $state eq "init" ) {
		if( m/^(\d\d\d)/ ) {
			$state = "keyid";
			$num = $1;
		}
	} elsif( $state eq "keyid" ) {
		if( m%^pub[^/]*/(\w*)% ) {
			$state = "user";
			$keyid = $1;
		}
	} elsif( $state eq "user" ) {
		if( m/^uid (.*)$/ ) {
			$state = "init";
			$uid = $1;
			print "$uid\t$keyid\t$num\n";
		}
	} else {
		die "BUG\n";
	}
}
