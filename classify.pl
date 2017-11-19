#!/usr/bin/env perl

use strict;
use warnings;
use DateTime;
use Data::Dumper;
use Getopt::Long qw(GetOptions);
use utf8;

use Helper;
use Classes;

use Archive;
my $archive = new Archive();

use Template;
my $template = Template->new('template.html');

# TODO
# Abstrahieren der einzelnen Funktionen
# Skript zum editieren des Dateinamens und loeschen aller Links und wieder anlegen aller Links
# Reklassifizierung implementieren
# Blacklist der entfernten Datume :)

my $actuallyDoSomething = 0;
my $dateOverwrite;
my $senderOverwrite;
my $tagsOverwrite;
my $tagsBlacklist = [];
my $tagsAppend = [];
my $searchYear;

GetOptions ("do" => \$actuallyDoSomething,
            "date=s" => \$dateOverwrite,
            "sender=s" => \$senderOverwrite,
            "tags=s" => \$tagsOverwrite,
            "notag=s@" => \$tagsBlacklist,
            "tag=s@" => \$tagsAppend,
            "year=s" => \$searchYear
) or die("Error in command line arguments\n");

if ( defined $dateOverwrite ) {
	if ( $dateOverwrite =~ /^(\d{2}).(\d{2}).(\d{4})$/ ) {
		$dateOverwrite = "$3-$2-$1";
	} elsif ( $dateOverwrite =~ /^\d{4}-\d{2}-\d{2}$/ ) {
	} else {
		print STDERR "Unsupported date format: $dateOverwrite\n";
		exit 1;
	}
}

if ( scalar @ARGV < 1 ) {
	print STDERR "Usage: $0 <pdffile>\n";
	exit 1;
}

my $htmlSearchYear = '';
if ( defined $searchYear ) {
	if ( $searchYear =~ /^(\d{2,4})$/ ) {
		$searchYear = $1;
		if ( $searchYear < 100 ) {
			$searchYear += 2000;
		}
		$htmlSearchYear = "-year '$searchYear'";
	} else {
		print STDERR "Unsupported search year: $searchYear\n";
		exit 1;
	}
} else {
	$searchYear = DateTime->now()->year();
}
$template->add('htmlSearchYear', ${htmlSearchYear});

my $filename = $ARGV[0];
if ( ! -f $filename ) {
	print STDERR "PDF file with name $filename does not exist\n";
	exit 1;
}
$template->add('filename', ${filename});

my $htmlFilename = $filename;
$htmlFilename =~ s/\.pdf$/.html/;
$htmlFilename =~ s/classify\//html\//;

my $classes = $Classes::regexps;

my $text = Helper::readPdf($filename);
$template->add('text', ${text});

if ( $actuallyDoSomething ) {
	open HTML, "> /dev/null" or die $!;
	if ( -f $htmlFilename ) {
		unlink $htmlFilename or warn $!;
	}
} else {
	open HTML, "> $htmlFilename" or die $!;
}
binmode (HTML, ':utf8');
select HTML;

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
if ( ! defined $dateOverwrite ) {
	$debugInformation .= '#'x50 . "\n";
	$debugInformation .= "# Finding dates in input\n";
	$debugInformation .= '#'x50 . "\n";

	for ( my $i = 0; $i < 4; $i++ ) {
		Helper::findDates($text, $info->{dates}, ($searchYear-$i), \$debugInformation);
	}

	foreach my $date ( keys %{$info->{dates}} ) {
		$info->{dates}->{$date}->{points} -= (($searchYear - substr($date, 0, 4))/2);
	}

	Helper::mergeDates($info->{dates});
} else {
	$info->{dates}->{$dateOverwrite} =  {
		count => 1,
		index => 0,
		overwrite => 1,
	};
}

# Apply all known regular expressions to guess tags and sender
foreach ( keys %$classes ) {
	my $class = $classes->{$_};
	$class->{regexp} = $_;

	foreach my $regexpText ( split "\n", $text ) {
		$regexpText =~ s/\s+//g;
		if ( $regexpText =~ /$class->{regexp}/i ) {
			$info->{regexp}->{$class->{regexp}} = 1;
			foreach ( @{$class->{tags}} ) {
				$info->{tags}->{$_}++;
			}
			if ( defined $class->{sender} ) {
				$info->{sender}->{$class->{sender}}++;
			}
			if ( defined $class->{dateIndex} ) {
				$info->{dateIndex} = $class->{dateIndex};
			}
		}
	}
}

if ( defined $senderOverwrite ) {
	$info->{sender} = {};
	$info->{sender}->{$senderOverwrite}++;
}

foreach my $tag ( @$tagsAppend ) {
	$info->{tags}->{$tag}++;
}

foreach my $tag ( @$tagsBlacklist ) {
	delete $info->{tags}->{$tag};
}

if ( defined $tagsOverwrite ) {
	$info->{tags} = {};
	foreach my $tag ( split ',', $tagsOverwrite ) {
		$info->{tags}->{$tag}++;
	}
}

sub dateSort {
	my $info = shift;
	my $a = shift;
	my $b = shift;

	if ( ($info->{dates}->{$a}->{points}/$info->{dates}->{$a}->{count}) == ($info->{dates}->{$b}->{points}/$info->{dates}->{$b}->{count}) ) {
		return $info->{dates}->{$a}->{index} <=> $info->{dates}->{$b}->{index};
	} else {
		return ($info->{dates}->{$b}->{points}/$info->{dates}->{$b}->{count}) <=> ($info->{dates}->{$a}->{points}/$info->{dates}->{$a}->{count});
	}
}

my @dates = sort { dateSort($info, $a, $b) } keys %{$info->{dates}};

my $primaryDate = '';
if ( scalar @dates ) {
	if ( defined $info->{dateIndex} && scalar @dates > $info->{dateIndex} ) {
		$primaryDate = $dates[$info->{dateIndex}];
	} else {
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
if ( scalar keys %{$info->{sender}} < 1 ) {
	$htmlSenderColor = 'red';
	my @senders = glob("store/sender/*");
	@senders = map { my $a = substr $_, length("store/sender/"); $a} @senders;
	$htmlSenderList = join "\n", map { "<option>$_</option>" } @senders;
	$htmlSenderList = "<select id=\"senderChoice\">\n$htmlSenderList\n</select>\n";
} elsif ( $filename =~ /$senderString/ ) {
	$htmlSenderColor = 'green';
}

	my @senders = glob("store/sender/*");
	@senders = map { my $a = substr $_, length("store/sender/"); $a} @senders;
	my $jsonSenderList = join ", ", map { "\"$_\"" } @senders;
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
if ( scalar keys %{$info->{tags}} < 1 ) {
	$htmlTagsColor = 'red';
	my @tags = glob("store/tags/*");
	@tags = map { my $a = substr $_, length("store/tags/"); $a} @tags;
	$htmlTagList = join "\n", map { "<option>$_</option>" } @tags;
	$htmlTagList = "<select>\n$htmlTagList\n</select>\n";

	my $jsonTagList = join ', ', map { "\"$_\"" } @tags;
	$template->add('jsonTagList', ${jsonTagList});
} elsif ( $filename =~ /-${tagString}\.pdf/ ) {
	$htmlTagsColor = 'green';
}
	my @tags = glob("store/tags/*");
	@tags = map { my $a = substr $_, length("store/tags/"); $a} @tags;
	my $jsonTagList = join ', ', map { "\"$_\"" } @tags;
	$template->add('jsonTagList', ${jsonTagList});
	my $htmlTagValueList = join(", ", map { "'$_'" } sort keys %{$info->{tags}});
	$template->add('htmlTagsValueList', ${htmlTagValueList});

$template->add('htmltaglist', ${htmlTagList});
$template->add('htmltags', ${htmlTags});
$template->add('htmltagscolor', ${htmlTagsColor});

if ( scalar keys %{$info->{sender}} < 1 || scalar keys %{$info->{tags}} < 1 || scalar keys %{$info->{dates}} < 1 ) {
	$debugInformation .= "Not enough information to generate complete filename\n";
	$bgcolor = 'red';
} elsif ( $actuallyDoSomething ) {

	$archive->addFile($filename, $primaryDate, [ keys %{$info->{sender}} ], [ keys %{$info->{tags}} ], $debugInformation);
}
$template->add('bgcolor', ${bgcolor});

my $htmlDo = '';
if ( $bgcolor eq 'green' ) {
	$htmlDo = '-do';
}
$template->add('htmlDo', ${htmlDo});

my @overrides;
#if ( defined $dateOverwrite ) {
#	push @overrides, "-date '$dateOverwrite'";
#}
#if ( defined $senderOverwrite ) {
#	push @overrides, "-sender '$senderOverwrite'";
#}
#if ( defined $tagsOverwrite ) {
#	push @overrides, "-tags '$tagsOverwrite'";
#}

foreach my $tag ( @$tagsAppend ) {
	push @overrides, "-tag '$tag'";
}

foreach my $tag ( @$tagsBlacklist ) {
	push @overrides, "-notag '$tag'";
}

my $htmlOverrides = join ' ', @overrides;
$template->add('htmlOverrides', ${htmlOverrides});

my $reclassify = '';
my $newFilename = $archive->genFilename($filename, $primaryDate, [ keys %{$info->{sender}} ], [ keys %{$info->{tags}}]);
if ( $filename eq "classify/$newFilename" ) {
	$reclassify = "background-color:yellow";
	if ( ! $actuallyDoSomething ) {
		print STDERR "./classify.pl ${htmlDo} ${htmlSearchYear} ${htmlOverrides} $filename\n";
	}
}
$template->add('reclassify', ${reclassify});

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
	$htmlSenderTags .= qq{</span>\n};
}
$template->add('htmlSenderTagList',$htmlSenderTags);

print $template->output();

