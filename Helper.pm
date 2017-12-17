package Helper;

use strict;
use warnings;
use Data::Dumper;
use utf8;

sub readPdf {
	my $filename = shift;

	open TXT, "pdftotext -l 1 $filename - |" or die $!;
	binmode (TXT, ':utf8');
	local $/;
	my $text = <TXT>;
	close TXT;

	return $text;
}

sub scoreDate {
	my $day = shift;
	my $month = shift;
	my $year = shift;

	my $points = 0;
	if ( defined $day && $day > 0 ) {
		$points += 2;
	}

	if ( length $month > 3 ) {
		$points += 1;
	}

	if ( length $year == 4 ) {
		$points +=2;
	}

	return $points;
}

sub verifyDate {
	# print "VerifyDate: " . Dumper(@_);
	my $day = shift;
	my $month = shift;
	my $year = shift;
	my $line = shift;
	my $searchYear = shift;
	my $debugInformation = shift;

	if ( !defined $day ) {
		$day = 0;
	}

	if ( $year < 100 ) {
		$year += 2000;
	}
	my $dateString = sprintf("%4d-%02d-%02d", $year, $month, $day);

	if ( $day < 0 || $day > 31 || $month < 1 || $month > 12 || $year < $searchYear || $year > $searchYear) {
		#$$debugInformation .= "Rejecting $dateString in >>$line<< with searchYear $searchYear\n";
		return undef;
	}

	my $dt = DateTime->new(
		year => $year,
		month => $month,
		time_zone => 'Europe/Berlin',
	);

	if ( $day > 0 && $day <= DateTime->last_day_of_month( year => $year, month => $month )->day ) {
		$dt->set_day($day);
	}

	if ( DateTime->compare($dt, DateTime->now()) > 0 ) {
		$$debugInformation .= "Rejecting $dateString in >>$line<< because it is in the future\n";
		return undef;
	}

	if ( $day == 12 && $month == 4 && ($year%100) == 84 ) {
		#$$debugInformation .= "Rejecting birthDate in >>$line<<\n";
		return undef;
	}

	$$debugInformation .= "Found $dateString in >>$line<<\n";
	return $dateString;
}

# TODO: Return list of lines, dates and score
sub findDates {
	my $text = shift;
	my $dates = shift;
	my $searchYear = shift;
	my $debugInformation = shift;

	my @lines = split "\n", $text;
	my $lineCounter = 0;
	foreach my $line ( @lines ) {
		$lineCounter++;
		my $shortSearchYear = $searchYear - 2000;
		$line =~ s/\s+//g;

		if ( $line =~ /$searchYear/ ) {
		} elsif ( $line =~ /$shortSearchYear/ ) {
		} else {
			# print "Does not contain year or short year\n";
			next;
		}

		if ( length ($line) < 6 ) {
			# print "Is shorter than six characters\n";
			next;
		}

		my %month = (
			Januar => 1,
			Jan => 1,
			Februar => 2,
			Feb => 2,
			Maerz => 3,
			'März' => 3,
			April => 4,
			Apr => 4,
			Mai => 5,
			Juni => 6,
			Juli => 7,
			August => 8,
			Aug => 8,
			September => 9,
			Sep => 9,
			Oktober => 10,
			Okt => 10,
			November => 11,
			Nov => 11,
			Dezember => 12,
			Dez => 12,
		);

		foreach my $monthName ( keys %month ) {
			#print "Trying regexp: /(\d{1,2})?\.?$monthName\.?(([12]\d)?$shortSearchYear)/ig\n";
			my $regexp = qr/(\d{1,2})?(\.|_|')?$monthName(([12]\d)?$shortSearchYear)/i;
			while ( ($line =~ /$regexp/ig) ) {
				my $dayString = $1;
				my $dayDot = $2;
				my $monthString = $monthName;
				my $yearString = $3;

				my $dateString = verifyDate($dayString, $month{$monthName}, $yearString, $line, $searchYear, $debugInformation);
				if ( ! defined $dateString ) {
					next;
				} else {
					if ( ! defined $dates->{$dateString} ) {
						$dates->{$dateString} = {};
					}
					if ( ! defined $dates->{$dateString}->{count} ) {
						$dates->{$dateString}->{count}=1;
					} else {
						$dates->{$dateString}->{count}++;
					}
					$dates->{$dateString}->{points} += scoreDate($dayString, $monthString, $yearString);

					if ( defined $dayDot && $dayDot eq '.' ) {
						$dates->{$dateString}->{points} += 1;
					}

					$dates->{$dateString}->{lineNumber} = $lineCounter;
					$dates->{$dateString}->{line} = $line;
					$dates->{$dateString}->{regexp} = $regexp;
				}
			}
		}

		#print "Trying regexp: /(\d{1,2})\.?(\d{1,2})\.?(([12]\d)?$shortSearchYear)/g\n";
		my $regexp = qr/(\d{1,2})(\.|_|')?(\d{1,2})(\.|_|')?(([12]\d)?$shortSearchYear)/;
		while ( ($line =~ /$regexp/g) ) {
			my $dayString = $1;
			my $dayDot = $2;
			my $monthString = $3;
			my $monthDot = $4;
			my $yearString = $5;

			my $dateString = verifyDate($dayString, $monthString, $yearString, $line, $searchYear, $debugInformation);
			if ( ! defined $dateString ) {
				next;
			} else {
				if ( ! defined $dates->{$dateString} ) {
					$dates->{$dateString} = {};
				}
				if ( ! defined $dates->{$dateString}->{index} ) {
					$dates->{$dateString}->{count}=1;
				} else {
					$dates->{$dateString}->{count}++;
				}
				$dates->{$dateString}->{points} += scoreDate($dayString, $monthString, $yearString);
				if ( defined $dayDot && $dayDot eq '.' ) {
					$dates->{$dateString}->{points} += 1;
				}
				if ( defined $monthDot && $monthDot eq '.' ) {
					$dates->{$dateString}->{points} += 1;
				}

				$dates->{$dateString}->{lineNumber} = $lineCounter;
				$dates->{$dateString}->{line} = $line;
				$dates->{$dateString}->{regexp} = $regexp;
			}
		}
	}
}

sub mergeDates {
	my $dates = shift;

	foreach my $dateKey ( keys %{$dates} ) {
		if ( $dateKey =~ /-00$/ ) {
			my $prefix = substr($dateKey, 0, 8);
			my @keys = grep(! /$dateKey/i, keys %{$dates});
			my @matches = grep(/^$prefix/i, @keys);
			if ( scalar @matches == 1 ) {
				$dates->{$matches[0]}->{count} += $dates->{$dateKey}->{count};
				if ( $dates->{$dateKey}->{index} < $dates->{$matches[0]}->{index} ) {
					$dates->{$matches[0]}->{index} = $dates->{$dateKey}->{index};
				}
				delete $dates->{$dateKey};
			}
		}
	}
}

1;
