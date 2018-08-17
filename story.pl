#!/usr/bin/env perl

# Write out all titles, descriptions and captions as one long story.

use strict;

########################################################################
### Classes
########################################################################

package Textfile;
use Class::Tiny qw/path/, {
  sec => sub { (stat($_[0]->path))[9] },
  date => sub {
    my @t = localtime $_[0]->sec;
    $t[5] += 1900;
    $t[4]++;
    sprintf "%04d-%02d-%02d", @t[5,4,3];
  },
  body => sub {
    open my $fh, '<', $_[0]->path or die;
    local $/ = undef;
    my $cont = <$fh>;
    close $fh;
    return $cont;
  },
  formatted => sub {
    my $text = $_[0]->body;
    $text =~ s/\s*<br[\s\/]*>\s*<br[\s\/]*>\s*/\n\n/ig;
    $text =~ s/\s*<br[\s\/]*>\s*/ /ig;
    $text =~ s/\s*$/\n/;
    return $text;
  },
  media => sub {
    my $path = $_[0]->path;
    $path =~ s,/caption.txt,,;
    opendir my $dir, $path;
    my($filename) = grep !/caption.txt/, grep !/^\./, readdir $dir;
    closedir $dir;
    return $filename;
  },
};

package Media;
use List::Util qw( sum );
use Class::Tiny qw/path/, {
  caption => sub {
    my $file = join '/', $_[0]->path, 'caption.txt';
    return unless -f $file;
    Textfile->new( path=>$file );
  },
  filename => sub {
    opendir my $dir, $_[0]->path;
    my($name) = grep !/caption.txt/, grep !/^\./, readdir $dir;
    closedir $dir;
    return $name;
  },
  filesec => sub {
    (stat(join '/', $_[0]->path, $_[0]->filename))[9]
  },
  sec => sub {
    my $self = shift;
    my @secs =
      $self->filesec,
      ( $self->caption ? $self->caption->sec : () );
    sum(@secs)/@secs;
  },
};

package Gallery;
use Class::Tiny qw/path/, {
  medias => sub {
    my $path = $_[0]->path;
    my @list;
    opendir my $dir, $path;
    for my $key ( grep !/description.txt/, grep !/^\./, readdir $dir ) {
      push @list, Media->new( path=>join '/', $path, $key );
    }
    return \@list;
  },
  captions => sub {
    [ grep { $_ } map $_->caption, @{$_[0]->medias} ]; 
  },
  formatted => sub {
    join '', map sprintf(
      "%s\t%s\t%s",
      $_->date,
      $_->media,
      $_->formatted,
    ), sort { $a->sec <=> $b->sec || $a->media->filename cmp $b->media->filename } @{$_[0]->captions};
  },
};

package Album;
use List::Util qw( sum );
use Class::Tiny qw/path/, {
  title => sub {
    opendir my $dir, $_[0]->path;
    my($title) = grep !/^\./, readdir $dir;
    closedir $dir;
    return $title;
  },
  description => sub {
    my $file = join '/', $_[0]->path, $_[0]->title, 'description.txt';
    return unless -f $file;
    Textfile->new( path => $file );
  },
  gallery => sub {
    Gallery->new( path => join '/', $_[0]->path, $_[0]->title );
  },
  sec => sub {
    my $self = shift;
    my @secs = (
      ( $self->description ? $self->description->sec : () ),
      ( map { $_->sec } @{$self->gallery->captions} ),
      ( map { $_->sec } @{$self->gallery->medias} ),
    );
    die $self->path unless @secs;
    int sum(@secs)/@secs;
  },
  date => sub {
    my @t = localtime $_[0]->sec;
    $t[5] += 1900;
    $t[4]++;
    sprintf "%04d-%02d-%02d", @t[5,4,3];
  },
  formatted => sub {
    my $self = shift;
    my $title = sprintf "%s\t%s\n",             $self->date,               $self->title ;
    my $delim = sprintf "%s\t%s\n", '-'x length($self->date), '-' x length($self->title);
    my $description = $self->description ? $self->description->formatted : '';
    my $captions    = $self->gallery->formatted;
    join '', $title, $delim, $description, $delim, $captions;
  },
};

package Project;
use Class::Tiny qw/path/, {
  albums => sub {
    opendir my $dir, $_[0]->path;
    my @list;
    for my $item ( grep !/^\./, readdir $dir ) {
      my $album = Album->new( path => join '/', $_[0]->path, $item );
      next unless $album->description or @{$album->gallery->medias}>0;
      push @list, $album;
    }
    closedir $dir;
    return \@list;
  },
  sorted => sub {
    [ sort { $a->sec <=> $b->sec } @{$_[0]->albums} ]
  }
};


########################################################################
### Main
########################################################################

package main;
my $project = Project->new(path => shift @ARGV );
my $delim = '#' x 72 . "\n";
for my $album ( @{ $project->sorted } ) {
  print $delim;
  print $album->formatted;
  print $delim;
}
