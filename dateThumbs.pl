#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Image::Magick;
use Data::Dumper;
use File::stat;

if ( ! -d 'store/archive' ) {
	print STDERR "store/archive not found\n";
	exit 1;
}

if ( -d 'store/archive' && ! -d 'store/archive/dateThumbs' ) {
	mkdir 'store/archive/dateThumbs';
}

foreach my $pdf ( glob ('store/archive/*.pdf') ) {
	my $basename = $pdf;
	$basename =~ s/.*\/([^\/]+).pdf/$1/;
	my $img = "store/archive/dateThumbs/$basename.jpg";

	if ( -e $img && (stat($pdf))->[9] <  (stat($img))->[9] ) {
		#print "$img is already up to date\n";
		next;
	}

	print "Updating $img\n";
	my $image = Image::Magick->new();
	$image->Set(density=>'300x300');
	$image->Read($pdf . '[0]');
	my ( $width, $height ) = $image->Get('width', 'height');

	my $startX = int(0.5*$width);
	my $startY = int(0.20*$height);

	if ( $pdf !~ /sent/ ) {
		$image->Crop(geometry=>sprintf '50%%x20%%+%d+%d', $startX, $startY);
	}
	$image->Set(quality=>90);
	$image->Write(filename=>$img);

}
