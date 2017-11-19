package Form;

use strict;
use warnings;
use utf8;
use Data::Dumper;

sub new {
	my $class = shift;

	my $self = {};
	$self->{paramRaw} = shift;
	$self->{defaults} = {};
	$self->{param} = {};

	bless $self;

	return $self;
}

sub clone {
	my $self = shift;
	my $copy = {};

	foreach my $name ( keys %{$self} ) {
		$copy->{$name} = { %{$self->{$name}} };
	}
	return bless $copy;
}

sub getParam {
	my $self = shift;
	my $name = shift;
	my $regexp = shift;
	my $default = shift;

	$self->{defaults}->{$name} = $default;

	if ( ! defined $self->{paramRaw}->{$name} || $self->{paramRaw}->{$name} !~ /$regexp/) {
		return $default;
	} elsif ( $self->{paramRaw}->{$name} eq $default ) {
		return $default;
	} else {
		$self->{param}->{$name} = $self->{paramRaw}->{$name};
		return $self->{param}->{$name};
	}
}

sub genOptions {
	my $options = shift;
	my $val = shift;
	my $retVal = '';

	foreach my $option ( @{$options} ) {
		my $selected = '';
		if ( ! defined $option->{display} ) {
			$option->{display} = $option->{value};
		}

		if ( $option->{value} eq $val ) {
			$selected = 'selected';
		}
		$retVal .= sprintf qq{<option value="%s" %s>%s</option>\n}, $option->{value}, $selected, $option->{display};
	}

	return $retVal;
}

sub getInputs {
	my $self = shift;
	my $blacklist = shift;
	my $retVal = '';

	foreach my $param ( keys %{$self->{param}} ) {
		if ( grep(/^$param$/, @$blacklist) ) {
		} else {
			$retVal .= sprintf qq{<input type="hidden" name="%s" value="%s"></input>\n}, $param, $self->{param}->{$param};
		}
	}

	return $retVal;
}

sub getParamString {
	my $self = shift;
	my $blacklist = shift;
	my $retVal = '?';

	foreach my $param ( keys %{$self->{param}} ) {
		if ( grep(/^$param$/, @$blacklist) ) {
		} else {
			$retVal .= sprintf qq{%s=%s&}, $param, $self->{param}->{$param};
		}
	}

	return $retVal;
}

sub setParam {
	my $self = shift;
	my $name = shift;
	my $value = shift;

	if ( defined $self->{defaults}->{$name} && $self->{defaults}->{$name} eq $value ) {
		delete $self->{param}->{$name};
	} else {
		$self->{param}->{$name} = $value;
	}

	return $self;
}

sub setParams {
	my $self = shift;

	foreach my $hsh ( @_ ) {
		$self->setParam($hsh->[0], $hsh->[1]);
	}

	return $self;
}

1;
