#!/usr/bin/env perl

use strict;
use warnings;
use DateTime;
use Data::Dumper;
use Getopt::Long qw(GetOptions);
use utf8;

use CGI;
use CGI::Carp qw(fatalsToBrowser);
my $q = new CGI;

print $q->header(-type => 'text/html', -charset => 'utf-8');

use FindBin;
use lib "$FindBin::Bin/../";

binmode STDOUT, ':utf8';
chdir '..' or die $!;

use Helper;
use Classes;

use Sender;

use Archive;
my $archive = new Archive();

use Template;
my $template = Template->new('template.html');

# TODO
# Abstrahieren der einzelnen Funktionen
# Skript zum editieren des Dateinamens und loeschen aller Links und wieder anlegen aller Links
# Reklassifizierung implementieren
# Blacklist der entfernten Datume :)

my $filename = $q->param('file');

if ( ! defined $filename || $filename eq '' || $filename !~ /^classify\/[^\/]+\.pdf$/ || ! -f $filename ) {
	my @files = glob("classify/*.pdf");
	foreach my $file ( @files ) {
		print qq{<a href="classify.pl?file=$file">$file</a><br>};
	}
	exit 0;
}

$template->add('filename', ${filename});

my $classes = $Classes::regexps;

my $text = Helper::readPdf($filename);
$template->add('text', ${text});

my $cls = "cls" . lc($filename);
$cls =~ s/[^\w\d]//g;
$cls =~ s/_//g;
$template->add('cls', ${cls});

my $info = {
	dates => {},
	tags => {},
	sender => {},
};

my $debugInformation;

# Search for lines which look like dates
$debugInformation .= '#'x50 . "\n";
$debugInformation .= "# Finding dates in input\n";
$debugInformation .= '#'x50 . "\n";

# Find dates in pdf text
my $monthRange = $q->param('month');
if ( $monthRange !~ /^\d+$/ ) {
	$monthRange = 3;
}
$monthRange *= -1;

my $searchYear = DateTime->now()->year();
my $endYear = DateTime->now()->add( months => $monthRange )->year();
$debugInformation .= "Looking for years $endYear - $searchYear\n";
for ( my $i = 0; $i <= ($searchYear-$endYear); $i++ ) {
	$debugInformation .= "Searching with year " . ($searchYear-$i) . "\n";
	Helper::findDates($text, $info->{dates}, ($searchYear-$i), \$debugInformation);
}

foreach my $date ( keys %{$info->{dates}} ) {
	$info->{dates}->{$date}->{points} -= (($searchYear - substr($date, 0, 4))/2);
}

Helper::mergeDates($info->{dates});

# Apply all known regular expressions to find tags and sender
my $matches = [];
foreach ( keys %$classes ) {
	my $class = $classes->{$_};
	$class->{regexp} = $_;

	foreach my $regexpText ( split "\n", $text ) {
		$regexpText =~ s/\s+//g;
		if ( $regexpText =~ /$class->{regexp}/i ) {
			push @$matches, {
				line => $regexpText,
				class => $class,
			}
		}
	}
}

# Matching over

foreach my $match ( @$matches ) {
	my $line = $match->{line};
	my $class = $match->{class};

	$info->{regexp}->{$class->{regexp}} = 1;
	foreach ( @{$class->{tags}} ) {
		$info->{tags}->{$_}++;
	}
	if ( defined $class->{sender} ) {
		$info->{sender}->{$class->{sender}}++;
		my $sndr = new Sender();
		$sndr->fromRegexp($class->{sender}, $line, $class);
		$info->{sender2} = $sndr;
	}
	if ( defined $class->{dateIndex} ) {
		$info->{dateIndex} = $class->{dateIndex};
	}
}

sub dateSort {
	my $info = shift;
	my $a = shift;
	my $b = shift;

	my $aPoints = ($info->{dates}->{$a}->{points}/$info->{dates}->{$a}->{count});
	my $bPoints = ($info->{dates}->{$b}->{points}/$info->{dates}->{$b}->{count});
	if ( $aPoints == $bPoints ) {
		return $info->{dates}->{$a}->{lineNumber} <=> $info->{dates}->{$b}->{lineNumber};
	} else {
		return $bPoints <=> $aPoints;
	}
}

sub dateSortByLineNumber {
	my $info = shift;
	my $a = shift;
	my $b = shift;

	return $info->{$a}->{lineNumber} <=> $info->{$b}->{lineNumber};
}


my $primaryDate = '';
if ( scalar keys %{$info->{dates}} ) {
	if ( defined $info->{dateIndex} && scalar keys %{$info->{dates}} > $info->{dateIndex} ) {
		my @dates = sort { dateSortByLineNumber($info->{dates}, $a, $b) } keys %{$info->{dates}};

		$debugInformation .= Dumper \@dates;
		$primaryDate = $dates[$info->{dateIndex}];
		$debugInformation .= "Choosing pos $info->{dateIndex} with information $dates[$info->{dateIndex}]\n";
	} else {
		my @dates = sort { dateSort($info, $a, $b) } keys %{$info->{dates}};
		$primaryDate = $dates[0];
	}
}

my $bgcolor = 'green';

my $htmlSenderList = '';
my $htmlSender = join(", ", sort keys %{$info->{sender}});
my $htmlSenderColor = 'white';
my $senderString = join("_", sort keys %{$info->{sender}});
$senderString =~ s/ /_/g;
$senderString =~ s/[^0\.\/\-\d\s\w]/_/g;
my $senders = $archive->getAllSenders();
if ( scalar keys %{$info->{sender}} < 1 ) {
	$htmlSenderColor = 'red';
	$htmlSenderList = join "\n", map { "<option>$_</option>" } @$senders;
	$htmlSenderList = "<select id=\"senderChoice\">\n$htmlSenderList\n</select>\n";
} elsif ( $filename =~ /$senderString/ ) {
	$htmlSenderColor = 'green';
}

my $jsonSenderList = join ", ", map { "\"$_\"" } @$senders;
$template->add('jsonSenderList', ${jsonSenderList});

if ( ${htmlSender} ne "" ) {
	$template->add('htmlSenderValueList', join(", ", map { "\"$_\"" } sort keys %{$info->{sender}}));
}

$template->add('htmlsender', ${htmlSender});
$template->add('htmlsendercolor', ${htmlSenderColor});
$template->add('htmlsenderlist', ${htmlSenderList});

my $htmlDateList = '';
my $htmlDate = $primaryDate;
$htmlDate =~ s/(\d{4})-(\d{2})-(\d{2})/$3.$2.$1/;

my $htmlDateColor = 'white';
if ( scalar keys %{$info->{dates}} < 1 ) {
	$htmlDateColor = 'red';
} elsif ( $filename =~ /$primaryDate/ ) {
	$htmlDateColor = 'green';
} elsif ( scalar keys %{$info->{dates}} > 1 ) {
	$htmlDateList = join "\n", map {
		my $date = $_;
		my $dateScore = $info->{dates}->{$date}->{points}/$info->{dates}->{$date}->{count};
		$date = "<option value=\"$date\">$date ($dateScore)</option>";
		$date =~ s/(\d{4})-(\d{2})-(\d{2})/$3.$2.$1/g;
		$date;
	} sort { dateSort($info, $a, $b) }keys %{$info->{dates}};
	$htmlDateList = "<select id=\"dateChoice\">\n<option value\"\" selected>\n$htmlDateList\n</select>\n";
}
$template->add('htmldate', ${htmlDate});
$template->add('htmldatecolor', ${htmlDateColor});
$template->add('htmldatelist', ${htmlDateList});

my $htmlTagList = '';
my $htmlTags = join(", ", sort keys %{$info->{tags}});
my $tagString = join("_", sort keys %{$info->{tags}});
my $htmlTagsColor = 'white';
my $tags = $archive->getAllTags();
if ( scalar keys %{$info->{tags}} < 1 ) {
	$htmlTagsColor = 'red';
	$htmlTagList = join "\n", map { "<option>$_</option>" } @$tags;
	$htmlTagList = "<select>\n$htmlTagList\n</select>\n";

	my $jsonTagList = join ', ', map { "\"$_\"" } @$tags;
	$template->add('jsonTagList', ${jsonTagList});
} elsif ( $filename =~ /-${tagString}\.pdf/ ) {
	$htmlTagsColor = 'green';
}

my $jsonTagList = join ', ', map { "\"$_\"" } @$tags;
$template->add('jsonTagList', ${jsonTagList});
my $htmlTagValueList = join(", ", map { "'$_'" } sort keys %{$info->{tags}});
$template->add('htmlTagsValueList', ${htmlTagValueList});

$template->add('htmltaglist', ${htmlTagList});
$template->add('htmltags', ${htmlTags});
$template->add('htmltagscolor', ${htmlTagsColor});

if ( scalar keys %{$info->{sender}} < 1 || scalar keys %{$info->{tags}} < 1 || scalar keys %{$info->{dates}} < 1 ) {
	$debugInformation .= "Not enough information to generate complete filename\n";
	$bgcolor = 'red';
}$template->add('bgcolor', ${bgcolor});

my $htmlDo = '';
if ( $bgcolor eq 'green' ) {
	$htmlDo = '-do';
}
$template->add('htmlDo', ${htmlDo});

my $newFilename = $archive->genFilename($filename, $primaryDate, [ keys %{$info->{sender}} ], [ keys %{$info->{tags}}]);

$debugInformation .= Dumper $info;
$template->add('debugInformation', ${debugInformation});

my $senderTags = $archive->getTagsOfSender();

my $htmlSenderTags = '';
foreach my $snd ( keys %{$senderTags} ) {
	my @tags;
	foreach my $tag ( sort keys %{$senderTags->{$snd}} ) {
		push @tags, "$tag ($senderTags->{$snd}->{$tag})";
	}
	$htmlSenderTags .= qq{<span id="senderTags$snd" class="senderTagItem"><b>$snd: </b>};
	$htmlSenderTags .= join ', ', @tags;
	$htmlSenderTags .= qq{<br></span>\n};
}
$template->add('htmlSenderTagList',$htmlSenderTags);

print $template->output();
