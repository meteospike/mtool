#!/usr/bin/perl -w

# Clone include and profile files associated to a given target name
# to an other one with respect to symbolic links.

use strict;

my ( $h1, $h2 ) = @ARGV;

die "usage: mkclone.pl source target\n"
  unless ( defined $h1 and defined $h2 );

for my $f ( <*$h1*> ) {
  ( my $target = $f ) =~ s/$h1/$h2/go;
  unless ( -e $target ) {
    if ( -l $f ) {
      my $l = readlink $f;
      print "link $l to $target\n";
      symlink $l, $target;
    } else {
      print "copy $f to $target\n";
      system( 'cp', $f, $target );
    }
  }
}
