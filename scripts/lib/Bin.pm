#!/usr/bin/env perl

use strict;
use warnings;

package Bin;

use Carp;

sub new {
	my $class = shift;

	my $self = {
		open => "right", # or "left"
		bins => [],
		tally => [],
	};
	foreach my $i ( 0..(@_-1) ) {
		push @{$self->{bins}}, $_[$i] if defined $_[$i];
	}
	$self->{bins} = [ sort { $a <=> $b } @{ $self->{bins} } ];

	zero($self);

	return bless $self, $class;
}

sub zero {
	my $self = shift;
	$self->{tally} = [ (0) x (@{ $self->{bins} } + 1) ];
}

sub add {
	my $self = shift;
	while( @_ ) {
		my $in = shift @_;

		my $b;
		for( $b = 0; $b < @{ $self->{bins} }; $b++ ) {
			if( $self->{open} eq "left" ) {
				if( $in <= $self->{bins}->[$b] ) {
					last;
				}
			} else {
				if( $in < $self->{bins}->[$b] ) {
					last;
				}
			}
		}
		$self->{tally}->[$b]++;
	}
}

unless(caller) {

use Data::Dumper;

my $age_bin = new Bin(0, 10, 20, 30);
my @test = (1,7,13,53,3,-3,25,10);
print "Add: ", join(", ", @test), "\n";
$age_bin->add(@test);
print Dumper($age_bin);

}

1;
