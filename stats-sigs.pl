#!/usr/bin/env perl

# do a web-of-trust analysis within the keys submitted for the KSP

use strict;
use warnings;
use List::Util qw/reduce/;
use DateTime;

my $basedir = "/var/ksp";
my $gpghome = "$basedir/output/gpg";

my $since = "2014-02-02";
my $until;
{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$until = sprintf "%04d-%02d-%02d", $year+1900, $mon+1, $mday;
}

{
	my (undef,undef,undef,undef,undef,undef,undef,undef,undef,$mtime,undef,undef,undef) = stat "$gpghome/pubring.gpg";
	if( $until !~ m/(\d\d\d\d)-(\d\d)-(\d\d)/ ) {
		die "invalid until date: $until";
	}
	my $u = DateTime->new(year => $1, month => $2, day => $3);
	if( $u->epoch() - $mtime > 86400 ) {
		print STDERR "\nWARNING: keyring is older that 1 day\n\n";
	}
}


open my $keys_fh, "gpg --homedir \"$gpghome\" --list-sigs --with-colons |"
	or die "Could not list keys";


my %sigs;
my %sigsby;
my %sigclass;

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
		$sigsby{$keyid} = {} unless exists $sigsby{$keyid};

	} elsif( m/^sub:([^:]*):(\d*):(\d*):([0-9A-Fa-f]*):([^:]*):([^:]*):():([^:]*):([^:]*):():([^:]*):/ ) {

	} elsif( m/^uid:/ ) {

	} elsif( m/^uat:/ ) {

	} elsif( m/^sig:([^:]*):(\d*):(\d*):([0-9A-Fa-f]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):/ ) {
		my ($validity, $keylength, $algo, $keyid, $create_date, $expire_date, $sn, $ownertrust, $uid, $sigclass, $cap) = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
		next if $uid eq "[User ID not found]";
		next unless $create_date ge $since;
		next unless $create_date le $until;
		next if $onto eq $keyid; # ignore self-sigs

		$sigs{$onto}->{$keyid}++;
		$sigsby{$keyid}->{$onto}++;
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

print "Statistics about the signatures since the event\n";
print "===============================================\n";
print "Signatures taken in to account are those made between $since and $until\n";
{
	my $numkeys = scalar( keys %sigs );
	my $total = 0;
	for my $v (values %sigs) {
		$total += scalar( keys %{$v} );
	}
	printf "%d new signatures between %d keys [1] (%0.1f new sigs / key)\n", $total, $numkeys, $total / $numkeys;
}
{
	my $mostsigs = ( sort { scalar(keys %{$sigs{$b}}) <=> scalar(keys %{$sigs{$a}}) } keys %sigs) [0];
	printf "%s made the most number of new signatures: %d\n", $mostsigs, scalar(keys %{$sigs{$mostsigs}} );
	$mostsigs = ( sort { scalar(keys %{$sigsby{$b}}) <=> scalar(keys %{$sigsby{$a}}) } keys %sigsby) [0];
	printf "%s received the most number of new signatures: %d\n", $mostsigs, scalar(keys %{$sigsby{$mostsigs}} );
}
printf "%d keys with no new signatures [2]\n", scalar(grep { scalar(keys %{$_}) == 0 } values %sigs);
printf "%d keys made no new signatures [2]\n", scalar(grep { scalar(keys %{$_}) == 0 } values %sigsby);
print "\n";
print "[1] a signature between keys is a signature on at least one UID of that key\n";
print "[2] GnuPG by default does not resign previously signed keys\n";
print "\n";
{
	print "Signature class popularity:\n";
	my $total = reduce { $a + $b } values %sigclass;
	foreach my $c (qw/10 11 12 13/) {
		printf "    %s : %d (%0.1f%%)\n", $c, $sigclass{$c}, $sigclass{$c}/$total*100;
	}
}
