package Sender;

use strict;
use warnings;
use utf8;

sub new {
	my $class = shift;
	my $self = {
		line => '',
		regexp => undef,
		name => '',
	};

	return bless $self, $class;
}

sub fromRegexp {
	my $self = shift;
	$self->{name} = shift;
	$self->{line} = shift;
	$self->{regexp} = shift;
}

1;
