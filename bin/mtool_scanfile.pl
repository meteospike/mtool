#!/usr/bin/perl -w 

use strict;

use FindBin qw ($Bin);
use lib "$Bin/../src";

use Mtool;
use Mtool::Shell;
use Getopt::Long;
use File::Find;
use File::Basename qw( dirname );

my %opts = (
  path     => undef,
  wait     => 1,
  log      => 1,
  old      => 3600,
  timeout  => 3600,
  retry    => 5,
  delay    => 30,
  size     => '1k',
  range    => undef,
  trace    => 1,
  verbose  => 1,
);

my @files = ();

GetOptions(
  \%opts,
  '<>' => sub { push @files, @_ },
  qw( path=s timeout=s retry=i delay=i old=s size=s range=s trace! verbose! wait! log!)
) or die "usage: mtool_scanfile.pl [--path=path-name] [--timeout=seconds] [--old=timeinsecs] [--retry=seconds] [--delay=seconds] [--size=min-size] [--range=term-range] [--[no]wait] [--[no]trace]  [--[no]verbose] [--[no]log]\n";

Mtool->fatal( "scanfile: no such directory ( $opts{path} )" )
  if ( defined $opts{path} and not -d $opts{path} );

my %fbytes = (
  k => 1024,
  m => 1024 * 1024,
  g => 1024 * 1024 * 1024,
);

if ( defined $opts{size} and $opts{size} =~ s/([\D])[ob]?$//i ) {
  Mtool->fatal( "scanfile: unkown unit size $1" )
    unless ( exists $fbytes{lc($1)} );
  $opts{size} = $opts{size} * $fbytes{lc($1)};
  Mtool->info( "scanfile: converting min size as $opts{size} bytes" );
}

my %ftime = (
  h => 3600,
  d => 86400,
);

for my $tval ( qw( old timeout ) ) {
  if ( defined $opts{$tval} and $opts{$tval} =~ /^(\d+)([hd])$/io ) {
    Mtool->fatal( "scanfile: unkown time period $2 for $tval" )
      unless ( exists $ftime{lc($2)} );
    $opts{$tval} = $1 * $ftime{lc($2)};
    Mtool->info( "scanfile: converting $tval to $opts{$tval} seconds" );
  }
}


chdir $opts{path} if defined $opts{path};

$opts{old} = $opts{old} / 86400.;

if ( defined $opts{range} ) {
   $opts{range} =~ s{\b(\d+)\-(\d+)(?:-(\d+))?\b}{
      my ( $begin, $end, $step ) = ( $1, $2, $3 );
      my @l = ();
      $step ||= 1;
      while ( $begin <= $end ) {
        push @l, $begin;
        $begin += $step;
      }
      join ',', @l;
   }egox;
   $opts{range} = [ split /\s*,\s*/o, $opts{range} ];
   my $fmt = '%0' . length( $opts{range}[0] ) . 'd';
   $opts{range} = [ map { sprintf "$fmt", $_ } @{$opts{range}} ];
   Mtool->info( "scanfile: range is @{$opts{range}}" );
   @files = map {
      my $file = $_;
      map { my $xf = $file; $xf =~ s/\(range\)/$_/o; $xf } @{$opts{range}}
   } @files;
}

my $sh = new Mtool::Shell;
$sh->set( '-x' ) if delete $opts{trace};

my %complete = ();
my %missing = ();
my $process = 1;

Mtool->info( "scanfile: candidates are [ @files ]" );

my $start = time();

while ( $process ) {

  for my $file (
    grep { $opts{old} <= 0 or -M "$_" < $opts{old} }
    grep { -f "$_" }
    grep { not $complete{$_} } @files
  ) {
    
    Mtool->info( "scanfile: look at $file" );

    my $size = -s $file;
    if ( $size < $opts{size} ) {
      Mtool->trouble( "scanfile: $file too small ($size bytes)" );
      next;
    }

    my $grow = 1;
    my $patience = 0;

    while ( $grow > 0 and $patience < 4 ) {
      Mtool->info( "scanfile: check grow $patience" );
      sleep $opts{retry};
      $patience += 1;
      $grow = -s $file;
      ( $grow, $size ) = ( $grow - $size, $grow );
    }

    $complete{$file} = 1 unless $grow;

  }

  if ( scalar(keys %complete) < scalar(@files) ) {
    if ( time() - $start < $opts{timeout} ) {
      Mtool->info( "scanfile: another little nap of $opts{delay} s." );
      sleep $opts{delay};
    } else {
      Mtool->trouble( "scanfile: run out of time ($opts{timeout} s.)" );
      $process = 0
    }
  } else {
    $process = 0
  }

}

my @troubles = ();

for ( grep { not $complete{$_} } @files ) {
  push @troubles, $_;
  Mtool->trouble( "scanfile: missing $_" );
}

unlink 'scanfile.log'
  if ( $opts{log} and -f 'scanfile.log' );

if ( $opts{log} and @troubles ) {
  open SCANLOG, '>scanfile.log' or die "Could not open scanfile.log\n";
  print SCANLOG "$_\n" for ( @troubles );
  close SCANLOG;
}

exit($opts{log} ? 0 : scalar(@troubles));

