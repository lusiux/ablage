package Archive;

use strict;
use warnings;
use utf8;
use Data::Dumper;
use Image::Magick;
use File::stat;

sub new {
	my $class = shift;

	my $self = {};

	foreach my $dir ( qw(archive sender tags year) ) {
		if ( ! -d "store/$dir" ) {
			mkdir "store/$dir" or die $!;
		}
	}

	my $obj = bless $self, $class;
	$obj->readInformation();
	return $obj;
}

sub readInformation {
	my $self = shift;

	my @files = glob ("store/archive/*.pdf");
	foreach my $file ( @files ) {
		$file =~ /\d{4}-\d{2}-\d{2}-([^-]+)-([^\.]+)(\.\d+)?\.pdf/;
		my $sender = $1;
		$self->{senders}->{$sender}++;
		$self->{tagsBySender}->{$sender}->{'_total'}++;
		my @tags = split '_', $2;
		foreach my $tag ( @tags ) {
			$self->{tags}->{$tag}++;
			$self->{tagsBySender}->{$sender}->{$tag}++;
		}
	}
}

sub updateIndex {
	my $self = shift;
	my $type = shift;
	my $filename = shift;

	foreach my $key ( @_ ) {
		my $newName = "store/$type/$key/";
		$newName =~ s/ /_/g;
		$newName =~ s/[^0\.\/\-\d\s\w]/_/g;
		if ( ! -d $newName ) {
			mkdir $newName;
		}

		if ( ! -f "$newName/$filename" ) {
			symlink "../../archive/$filename", "$newName/$filename" or warn $!;
		}
	}
}

sub addFile {
	my $self = shift;

	my $file = shift;
	my $date = shift;
	my $sender = shift;
	my $tags = shift;
	my $debugInformation = shift;

	my $newFilename = $self->genFilename($file, $date, $sender, $tags, $debugInformation);

	rename $file, "store/archive/$newFilename" or warn $!;
	print STDOUT "Archived as $newFilename\n";

	$self->updateIndex('sender', $newFilename, @$sender);
	$self->updateIndex('tags', $newFilename, @$tags);

	my $year = $date;
	$year =~ s/^(\d{4}).*/$1/;
	$self->updateIndex('year', $newFilename, $year);

	# $self->genDateThumb($newFilename);
	return $newFilename;
}

sub genDateThumb {
	my $self = shift;
	my $filename = shift;

	my $filepath = "store/archive/$filename";

	my $img = $filename;
	$img =~ s/\.pdf$/.jpg/;
	$img = "store/archive/dateThumbs/$img";

	if ( -e $img ) {
		my $filepathStat = stat($filepath);
		my $imgStat = stat($img);
		if ( $filepathStat->mtime < $imgStat->mtime ) {
			return;
		}
	}

	print STDERR "Updating date thumbnail\n";

	my $image = Image::Magick->new();
	#$image->Set(density=>'300x300');
	$image->Read($filepath . '[0]');
	my ( $width, $height ) = $image->Get('width', 'height');

	my $startX = int(0.5*$width);
	my $startY = int(0.20*$height);

	if ( $filename !~ /sent/ ) {
		$image->Crop(geometry=>sprintf '50%%x20%%+%d+%d', $startX, $startY);
	}
	$image->Set(quality=>90);
	$image->Write(filename=>$img);
}

sub genFilename {
	my $self = shift;

	my $file = shift;
	my $date = shift;
	my $sender = shift;
	my $tags = shift;
	my $debugInformation = shift;

	my $counter = 0;

	my $newFilename = '';
	while ( 1 ) {
		$newFilename = $self->genFilenameWithoutCheck($file, $date, $sender, $tags, $counter, $debugInformation);

		if ( -f "store/archive/$newFilename" ) {
			print STDERR "store/archive/$newFilename already exists\n";
			$counter++;
			next;
		} else {
			last;
		}
	}

	return $newFilename;
}

sub genFilenameWithoutCheck {
	my $self = shift;

	my $file = shift;
	my $date = shift;
	my $sender = shift;
	my $tags = shift;
	my $counter = shift;
	my $debugInformation = shift;

	my $newFilename;
	if ( $counter > 0 ) {
		$newFilename = sprintf '%s-%s-%s.%d.pdf', $date, join('_', sort @$sender), join('_', sort @$tags), $counter;
	} else {
		$newFilename = sprintf '%s-%s-%s.pdf', $date, join('_', sort @$sender), join('_', sort @$tags);
	}

	$newFilename =~ s/ /_/g;
	$newFilename =~ s/[^0\.\/\-\d\s\w]/_/g;

	if ( defined $debugInformation ) {
		$$debugInformation .= '#'x50 . "\n";
		$$debugInformation .= "# Rename\n";
		$$debugInformation .= '#'x50 . "\n";
		$$debugInformation .= "$file -> $newFilename\n";
		$$debugInformation .= '#'x50 . "\n";
		$$debugInformation .= "# Debug information\n";
		$$debugInformation .= '#'x50 . "\n";
	}

	return $newFilename;
}

sub getTagsOfSender {
	my $self = shift;

	return $self->{tagsBySender};
}

sub getAllTags {
	my $self = shift;

	return [ sort keys %{$self->{tags}} ];
}

sub getAllSenders {
	my $self = shift;

	return [ sort keys %{$self->{senders}} ];
}

1;
