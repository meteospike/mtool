#!/usr/bin/perl -w 

use strict;

use FindBin qw ($Bin);
use lib "$Bin/../src";

use Mtool;
use Text::Banner;
use Getopt::Long;

my @moretext = ();

my %opts = (
  string => '',
  line   => 0,
  top    => 0,
  bottom => 0,
  size   => 1,
  char   => '#',
  lchar   => '=',
  rotate => 'H',
);

GetOptions(
  \%opts,
  '<>' => sub { push @moretext, @_ },
  qw( string=s line=i top=i bottom=i char=s size=i rotate=s lchar=s )
) or die "usage: mtool_banner.pl [--string=banner-text] --size=char-size] [--char=fill-char] [--rotate=H|V] [line=length-of-line] [banner-text]...\n";

$opts{string} = join ' ', grep /\S/o, $opts{string}, @moretext;
$opts{string} = 'VIVA MTOOL' unless ( $opts{string} =~ /\S/o );

my $b = new Text::Banner;

$b->rotate( $opts{rotate} );
$b->size( $opts{size} );
$b->fill( $opts{char} );
$b->set( $opts{string} );

my $top = $opts{top} > $opts{line} ? $opts{top} : $opts{line};
print $opts{lchar} x $top, "\n\n" if ( $top );

print $b->get();

my $bottom = $opts{bottom} > $opts{line} ? $opts{bottom} : $opts{line};
print $opts{lchar} x $bottom, "\n\n" if ( $bottom );

