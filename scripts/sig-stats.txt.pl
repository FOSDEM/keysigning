#!/usr/bin/env perl

# do a web-of-trust analysis within the keys submitted for the KSP

use strict;
use warnings;
use List::Util qw/reduce/;
use DateTime;

use File::Temp qw/tempdir/;

my $keyring = "keyring.gpg";
if( @ARGV == 1 ) {
	$keyring = $ARGV[0];
}

my $since = "2015-02-01";
my $until;
{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$until = sprintf "%04d-%02d-%02d", $year+1900, $mon+1, $mday;
}

my $tempdir = tempdir(CLEANUP => 1);
my $rv = system("gpg", "--homedir", $tempdir, "-q", "--import", $keyring) >> 8;
if( $rv != 0 ) { die "Could not import keyring"; }

{
	my (undef,undef,undef,undef,undef,undef,undef,undef,undef,$mtime,undef,undef,undef) = stat $keyring;
	if( $until !~ m/(\d\d\d\d)-(\d\d)-(\d\d)/ ) {
		die "invalid until date: $until";
	}
	my $u = DateTime->new(year => $1, month => $2, day => $3);
	if( $u->epoch() - $mtime > 86400 ) {
		print STDERR "\nWARNING: keyring is older that 1 day\n\n";
	}
}


open my $keys_fh, "gpg --homedir \"$tempdir\" --list-sigs --with-colons |"
	or die "Could not list keys";


my @keyid;
my %sigs;
my %uid;
my %sigclass = (10=>0, 11=>0, 12=>0, 13=>0);

my %algo = (
	1 => "RSA",		# RSA (Encrypt or Sign) [HAC]
	2 => "RSA",		# RSA Encrypt-Only [HAC]
	3 => "RSA",		# RSA Sign-Only [HAC]
	16 => "ElGamal",	# Elgamal (Encrypt-Only) [ELGAMAL] [HAC]
	17 => "DSA",		# DSA (Digital Signature Algorithm) [FIPS186] [HAC]
	18 => "EC",		# Reserved for Elliptic Curve
	19 => "ECDSA",		# Reserved for ECDSA
	20 => "ElGamal",	# Reserved (formerly Elgamal Encrypt or Sign)
	21 => "DH",		# Reserved for Diffie-Hellman (X9.42, as defined for IETF-S/MIME)
);

my ($onto);
while(<$keys_fh>) {
	if( m/^pub:([^:]*):(\d*):(\d*):([0-9A-Fa-f]*):([^:]*):([^:]*):():([^:]*):([^:]*):():([^:]*):/ ) {
		my ($validity, $keylength, $algo, $keyid, $create_date, $expire_date, $sn, $ownertrust, $uid, $sigclass, $cap) = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
		$onto = $keyid;
		$sigs{$keyid} = {};
		$uid{$keyid} = $uid;
		push @keyid, $keyid;

	} elsif( m/^sub:([^:]*):(\d*):(\d*):([0-9A-Fa-f]*):([^:]*):([^:]*):():([^:]*):([^:]*):():([^:]*):/ ) {

	} elsif( m/^uid:/ ) {

	} elsif( m/^uat:/ ) {

	} elsif( m/^sig:([^:]*):(\d*):(\d*):([0-9A-Fa-f]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):/ ) {
		my ($validity, $keylength, $algo, $keyid, $create_date, $expire_date, $sn, $ownertrust, $uid, $sigclass, $cap) = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
		next if $uid eq "[User ID not found]";
		next if $onto eq $keyid; # ignore self-sigs

		if( $create_date lt $since ) {
			$sigs{$onto}->{$keyid} = "P";
		} elsif( $create_date le $until ) {
			$sigs{$onto}->{$keyid} = "F";
		}
		if( $sigclass =~ m/^(10|11|12|13)/ ) {
			$sigclass{ $1 }++;
		} else {
			print STDERR "Unknown signature class: $sigclass\n";
		}

	} elsif( m/^rev:/ ) {

	} elsif( m/^tru:/ ) {
		# Trust database info, ignore

	} else {
		print STDERR "Unrecognized line: $_";
	}
}

sub rows_to_cols {
	my ($x, $p, $j, $i) = @_;
# print @$x vertically, with $p spaces between the enties, $j alligned (0=top, 1=bottom)
# start every line with $i
	my $m = 0; map { $m = length $_ if $m < length $_ } @$x;
	($j||0) && map { $_ = sprintf "%*s", $m, $_ } @$x;
	@_ =  map { ($")x(defined $p ? $p : 2),$_ } @$x;
	map { print "$i"; map { my $t = substr($_, 0, 1, ""); print (defined $t ? $t : $") } @_; print $/ } 1..$m
}


print "Signature matrix\n";
print "================\n";
print "is row signed by column?\n";
my ($Psigs, $Fsigs, $maxsigs) = (0,0,0);
rows_to_cols [1..@keyid], 0, 1, "      ";
for my $onton (1..@keyid) {
	$onto = $keyid[$onton-1];
	printf "%3d  |", $onton;
	for my $byn (1..@keyid) {
		my $by = $keyid[$byn-1];
		if( $onto eq $by ) {
			print "\\";
		} elsif( ! defined $sigs{$onto}->{$by} ) {
			print " ";
			$maxsigs++;
		} elsif( $sigs{$onto}->{$by} eq "P" ) {
			print "x";
			$Psigs++;
			$maxsigs++;
		} elsif( $sigs{$onto}->{$by} eq "F" ) {
			print "X";
			$Fsigs++;
			$maxsigs++;
		}
	}
	print "|   $onto $uid{$onto}\n";
}
printf "Signatures before %s \"x\": %d/%d (%0.1f%%)\n", $since, $Psigs, $maxsigs, $Psigs/$maxsigs*100;
printf "Signatures since %s \"X\": %d/%d (%0.1f%%)\n", $since, $Fsigs, $maxsigs, $Fsigs/$maxsigs*100;
printf "Total signatures: %d/%d (%0.1f%%)\n", ($Fsigs+$Psigs), $maxsigs, ($Fsigs+$Psigs)/$maxsigs*100;

print "\n";
{
	print "Signature class popularity:\n";
	our ($a, $b); # dummy, to silence warnings
	my $total = reduce { $a + $b } values %sigclass;
	foreach my $c (qw/10 11 12 13/) {
		printf "    %s : %d (%0.1f%%)\n", $c, $sigclass{$c}, $sigclass{$c}/$total*100;
	}
}
