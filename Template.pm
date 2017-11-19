package Template;
use utf8;

sub new {
	my $class = shift;
	my $self = {};

	$self->{filename} = shift;

	return bless $self, $class;
}

sub add {
	my $self = shift();
	my $key = lc(shift);
	my $value = shift;

	$self->{data}->{$key} = $value;
}

sub output {
	my $self = shift;
	my $output = '';

	open TMP, '<:utf8', $self->{filename} or die $!;

	while ( (my $line = <TMP>) ) {
		while ( $line =~ /%%([^%]+)%%/i ) {
			my $tmplKey = lc($1);
			$line =~ s/%%$tmplKey%%/$self->{data}->{$tmplKey}/i;
		}
		$output .= $line;
	}

	return $output;
}

1;
