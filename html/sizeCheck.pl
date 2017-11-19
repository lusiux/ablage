#!/usr/bin/env perl

use strict;
use warnings;
use DateTime;
use Data::Dumper;
use Getopt::Long qw(GetOptions);
use Image::Magick;
use utf8;

use CGI;
use CGI::Carp qw(fatalsToBrowser);
my $q = new CGI;

print $q->header(-type => 'text/html', -charset => 'utf-8');

use FindBin;
use lib "$FindBin::Bin/../";

use Helper;
use Template;
use Form;

print qq{
	<table>
};

my $param = new Form(scalar $q->Vars);

my $tag = $param->getParam('tag', '[^\/]+', undef);
my $sender = $param->getParam('sender', '[^\/]+', undef);
my $year = $param->getParam('year', '\d{4}', '2017');

my $path = "../store/";

if ( defined $sender && -d "$path/sender/$sender" ) {
	$path .= "sender/$sender";
} elsif ( defined $tag && -d "$path/tags/$tag" ) {
	$path .= "tags/$tag";
} elsif ( defined $year && -d "$path/year/$year" ) {
	$path .= "year/$year";
}

foreach my $pdf ( glob("$path/*.pdf") ) {
	my $basename = $pdf;
	$basename =~ s/.+\/([^\/]+)\.pdf$/$1/;
	my $img = "dateThumbs/$basename.jpg";

	my $image = Image::Magick->new();
	$image->Read($img);
	my ( $width, $height ) = $image->Get('width', 'height');

	if ( $pdf =~ /sent/ && $width > 1999 ) {
		next;
	} elsif ( $width > 999 ) {
		next;
	}

	my $dateStr = '';
	if ( $pdf =~ /(\d{4})-(\d{2})-(\d{2})/ ) {
		$dateStr = "$3.$2.$1";
	}

	print qq{
	<tr>
		<td>
			$basename.pdf
		</td>
		<td>
			$dateStr
		</td>
		<td>
	};
	if ( -e $img ) {
		print qq{
			<img style="width:60%;border:1px solid black" src="$img">
		};
	}

	print qq{
		</td>
	</td>
	};
}

print qq{
	</table>
};
