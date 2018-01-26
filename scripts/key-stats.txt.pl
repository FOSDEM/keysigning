#!/usr/bin/env perl

# Generate some statistics on the keys

use strict;
use warnings;
use List::Util qw/reduce/;
use DateTime;

use File::Temp qw/tempdir/;

use FindBin;
use lib $FindBin::Bin . "/lib";
use Bin;

my $keyring = "keyring.gpg";
if( @ARGV == 1 ) {
	$keyring = $ARGV[0];
}

my $now = time;
my $now_str;
{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($now);
	$now_str = sprintf "%d-%02d-%02d", $year+1900, $mon+1, $mday;
}

my @age_bins = (
	["0d", 0],
	["1d", 1],
	["1w", 7],
	["1m", 365.24/12*1],
	["2m", 365.24/12*2],
	["6m", 365.24/12*6],
	["1y", 365.24],
	["2y", 2*365.24],
	["5y", 5*365.24],
	["10y", 10*365.24],
);
my $age_key = new Bin(map { $_->[1] } @age_bins);
my $age_ssig = new Bin(map { $_->[1] } @age_bins);


my $tempdir = tempdir(CLEANUP => 1);
my $rv = system("gpg", "--homedir", $tempdir, "-q", "--import", $keyring) >> 8;
if( $rv != 0 ) { die "Could not import keyring"; }

open my $keys_fh, "gpg --homedir \"$tempdir\" --list-sigs --with-colons --fixed-list-mode |"
	or die "Could not list keys";

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
	22 => "EDDSA",		# https://tools.ietf.org/html/draft-koch-eddsa-for-openpgp-04 used by GnuPG 2.1
);

my %algolength_master;
my $numkeys;

my ($onto);
my $most_recent_ssig = undef;
while(<$keys_fh>) {
	if( m/^pub:([^:]*):(\d*):(\d*):([0-9A-Fa-f]*):([^:]*):([^:]*):():([^:]*):([^:]*):():([^:]*):/ ) {
		my ($validity, $keylength, $algo, $keyid, $create_date, $expire_date, $sn, $ownertrust, $uid, $sigclass, $cap) = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
		if( defined $most_recent_ssig ) {
			$age_ssig->add( $most_recent_ssig );
		}
		$most_recent_ssig = undef;

		$onto = $keyid;

		$algolength_master{ $algo{$algo} }->{ $keylength }++;
		$numkeys++;
		$age_key->add( ($now - $create_date)/86400 );

	} elsif( m/^sub:([^:]*):(\d*):(\d*):([0-9A-Fa-f]*):([^:]*):([^:]*):():([^:]*):([^:]*):():([^:]*):/ ) {

	} elsif( m/^uid:/ ) {

	} elsif( m/^fpr:/ ) {

	} elsif( m/^uat:/ ) {

	} elsif( m/^sig:([^:]*):(\d*):(\d*):([0-9A-Fa-f]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):/ ) {
		my ($validity, $keylength, $algo, $keyid, $create_date, $expire_date, $sn, $ownertrust, $uid, $sigclass, $cap) = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
		next if $uid eq "[User ID not found]";

		if( $keyid eq $onto ) { # Self sig
			my $delta = ($now - $create_date)/86400;
			if( ! defined $most_recent_ssig || $delta < $most_recent_ssig ) {
				$most_recent_ssig = $delta;
			}
		}

	} elsif( m/^rvk:/ ) {
	} elsif( m/^rev:/ ) {
	} elsif( m/^tru:/ ) {
	} else {
		print STDERR "Unrecognized line: $_";
	}
}
if( defined $most_recent_ssig ) {
	$age_ssig->add( $most_recent_ssig );
}


print "Statistics about the keys submitted\n";
print "===================================\n";
{
	printf "Breakdown by popularity of algorithm and length of master key:\n";

	my %algo_master = map { ($_, reduce { $a + $b } values %{$algolength_master{$_}}) } keys %algolength_master;
	my $numkeys = reduce { $a + $b } values %algo_master;

	printf "  Total: %d\n", $numkeys;
	for my $al (sort { $algo_master{$b} <=> $algo_master{$a} } keys %algo_master) {
		printf "    %s : %d (%0.1f%%)\n", $al, $algo_master{$al}, $algo_master{$al}/$numkeys*100;
		for my $l ( sort { $algolength_master{$al}->{$b} <=> $algolength_master{$al}->{$a} } keys %{$algolength_master{$al}} ) {
			printf "      %5d : %d (%0.1f%% of %s, %0.1f%% of total)\n",
				$l, $algolength_master{$al}{$l}, $algolength_master{$al}{$l}/$algo_master{$al}*100, $al,
				$algolength_master{$al}{$l}/$numkeys*100;
		}
	}
}
print "\n";
{
	print "Master key age breakdown by creation date (reference date: $now_str):\n";
	printf "    %d keys younger than %s\n", $age_key->{tally}->[0], $age_bins[0]->[0];
	for my $i (0..(@age_bins-1)) {
		printf "    %d keys older than %s\n", $age_key->{tally}->[$i+1], $age_bins[$i]->[0];
	}
}
print "\n";
{
	print "Master key age breakdown by date of last selfsig (reference date: $now_str):\n";
	printf "    %d self-sigs younger than %s\n", $age_ssig->{tally}->[0], $age_bins[0]->[0];
	for my $i (0..(@age_bins-1)) {
		printf "    %d self-sigs older than %s\n", $age_ssig->{tally}->[$i+1], $age_bins[$i]->[0];
	}
}
