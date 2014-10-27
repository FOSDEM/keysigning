#!/usr/bin/env perl

# Generate some statistics on the keys

use strict;
use warnings;
use List::Util qw/reduce/;
use DateTime;

use FindBin;
use lib $FindBin::Bin;
use Bin;

my $basedir = "/var/ksp";
my $gpghome = "$basedir/output/gpg";
my $now = DateTime->now;
#$now = DateTime->new( year => 2014, month => 2, day => 2 );

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


open my $keys_fh, "gpg --homedir \"$gpghome\" --list-sigs --with-colons |"
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
		if( $create_date =~ m/(\d\d\d\d)-(\d\d)-(\d\d)/ ) {
			my $cd = DateTime->new( year => $1, month => $2, day => $3 );
			my $delta = $cd->delta_days( $now );
			$age_key->add( $delta->in_units('days') );
		} else {
			die "Invalid create_date: $create_date";
		}

	} elsif( m/^sub:([^:]*):(\d*):(\d*):([0-9A-Fa-f]*):([^:]*):([^:]*):():([^:]*):([^:]*):():([^:]*):/ ) {

	} elsif( m/^uid:/ ) {

	} elsif( m/^uat:/ ) {

	} elsif( m/^sig:([^:]*):(\d*):(\d*):([0-9A-Fa-f]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):/ ) {
		my ($validity, $keylength, $algo, $keyid, $create_date, $expire_date, $sn, $ownertrust, $uid, $sigclass, $cap) = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
		next if $uid eq "[User ID not found]";

		if( $keyid eq $onto ) { # Self sig
			if( $create_date =~ m/(\d\d\d\d)-(\d\d)-(\d\d)/ ) {
				my $cd = DateTime->new( year => $1, month => $2, day => $3 );
				my $delta = $cd->delta_days( DateTime->now );
				$delta = $delta->in_units('days');
				if( ! defined $most_recent_ssig || $delta < $most_recent_ssig ) {
					$most_recent_ssig = $delta;
				}
			} else {
				die "Invalid create_date: $create_date";
			}
		}

	} elsif( m/^rev:/ ) {

	} elsif( m/^tru:/ ) {
		# Trust database info, ignore

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
	print "Master key age breakdown by creation date:\n";
	printf "    %d keys younger than %s\n", $age_key->{tally}->[0], $age_bins[0]->[0];
	for my $i (0..(@age_bins-1)) {
		printf "    %d keys older than %s\n", $age_key->{tally}->[$i+1], $age_bins[$i]->[0];
	}
}
print "\n";
{
	print "Master key age breakdown by date of last selfsig:\n";
	printf "    %d self-sigs younger than %s\n", $age_ssig->{tally}->[0], $age_bins[0]->[0];
	for my $i (0..(@age_bins-1)) {
		printf "    %d self-sigs older than %s\n", $age_ssig->{tally}->[$i+1], $age_bins[$i]->[0];
	}
}
