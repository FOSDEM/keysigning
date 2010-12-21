#!/usr/bin/perl -w

################################################################################
# LookUpKeyStats.pl tries to fetch some useful statistical data from
# Henk Pennings side ($urlBase) to enrich any given "List of Participants" prior
# to Keysigning-Parties.
#
# Usage: ./LookUpKeyStats.pl LIST-OLD > LIST-NEW
#
# Each of the given keyblocks will than have a seperate line showing
# NUMBER_OF SIGNATURES, NUMBER_OF_KEYS_SIGNED, CURRENT_MSD and CURRENT_RANK
# Keys not known to the keyserver simply will have [0000] entries.
#
# Released under GPL. Karlheinz "streng" Geyer <streng@ftbfs.de>
################################################################################
use URI::Escape;
use LWP::UserAgent;

$ua = LWP::UserAgent->new();

$urlBase = "http://pgp.cs.uu.nl/stats/[:KEY:].html";

$state = 0;

resetValues();

while (<>) {
  chomp;
  SWITCH: {
    $state == 0 && do {
      /^pub / && do {
        $state=1;
        $thekey=$_;
        $thekey =~ s/^[^\/]*\/(........).*/$1/gi;
        lookupStats($thekey);
      };
      print "$_\n"; last SWITCH; };
    $state == 1 && do {
        /^--* */ && do {
        $state=0;
        printf("Signatures:[%05d]   Keys signed:[%06d]   MSD:[%1.4f]   Rank:[%06d]\n", $signatures, $keyssigned, $msd, $rank);
        resetValues();
      };
      print "$_\n"; last SWITCH; };
  }

  
}


sub lookupStats {
  my $fk = shift;
  my $url = $urlBase;
  $url =~ s/\[:KEY:\]/$fk/g;
        
  my $request = HTTP::Request->new('GET', $url);
    
  my $response = $ua->request($request);
    
  if ( $response->is_error() ) {
    print STDERR "Could not load statistics for key $fk:\n";
    print STDERR "Error received when loading: $url\n";
    print STDERR "Error-Code    : ", $response->code() ,    "\n";
    print STDERR "Error-Message : ", $response->message() , "\n";
  }
  else {
    for (split("\n",$response->content())){
      /^\<TR\>\<TD *\>signatures/ && do {
        chomp;
        s/\<[^\>]*\>//gi;
        s/[a-z\(\)\<\> \t]//gi;
        $signatures=$_;};
      /^\<TR\>\<TD \>keys signed/ && do {
        chomp;
        s/\<[^\>]*\>//gi;
        s/[a-z\(\)\<\> \t]//gi;
        $keyssigned=$_;};
      /^\<TR\>\<TD \>mean shortest distance/ && do {
        chomp;
        s/\<[^\>]*\>//gi;
        s/[a-z\(\)\<\> \t]//gi;
        $msd=$_;};
      /^\<TR\>\<TD \>msd ranking/ && do {
        chomp;
        s/\<[^\>]*\>//gi;
        s/[a-z\(\)\<\> \t]//gi;
        $rank=$_;};
    }
    
  }

}

sub resetValues {
  $thekey="";
  $signatures=0;
  $keyssigned=0;
  $msd=0.0;
  $rank=0;
}

