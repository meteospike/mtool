#!/usr/bin/perl -w 

use strict;

use FindBin qw ($Bin);
use lib "$Bin/../src";

use Mtool;
use Mtool::Shell;
use Mtool::Bin::Track;
use Mtool::Bin::Import;
use Getopt::Long;

my %opts = (
  depot     => $ENV{MTOOL_STEP_DEPOT} || $ENV{PWD},
  rpath     => $ENV{MTOOL_STEP_SPOOL} || undef,
  root      => $ENV{PWD},
  type      => undef,
  filter    => '.',
  discard   => '__none__',
  tag       => 'misc',
  deep      => 1,
  trace     => 1,
  reset     => 0,
  verbose   => 0,
  bcast     => undef,
  delay     => 1,
  packing   => undef,
  packmin   => $ENV{MTOOL_IMPORT_PACKMIN} || 10,
  packbig   => $ENV{MTOOL_IMPORT_PACKBIG} || 32,
);

GetOptions(
  \%opts,
  qw( depot=s bcast=s type=s root=s tag=s filter=s discard=s packmin=i deep! trace! reset! verbose! delay! packing! )
) or die "usage: mtool_track.pl\n  --type=env|fs\n  [--tag=tag-name]\n  [--depot=path-name]\n  [--root=root-path]\n  [--bcast=broadcast-file-name]\n  [--filter=positive-filter]\n  [--discard=negative-filter]\n  [--packmin=minimum-items-for-packing]\n  [--[no]deep]\n  [--[no]reset]\n  [--[no]trace]\n  [--[no]packing]\n  [--[no]verbose]\n";

Mtool->fatal( "$opts{depot}: no such directory" )
  unless ( -d "$opts{depot}" );

Mtool->fatal( "track: a type must be set" )
  unless ( defined $opts{type} );

my $sh = new Mtool::Shell( -tag => 'mtoolkit' );

$sh->set( '-x' ) if delete $opts{trace};

my $track = new Mtool::Bin::Track;

for my $type ( sort split /,/,delete $opts{type} ) {

  my @upd = $track->process( %opts, -type => $type );

  if ( $opts{bcast} ) {
    if ( @upd ) {

      $opts{packing} = $sh->switch( qw( MTOOL_IMPORT_PACKING ) )
        unless ( defined $opts{packing} );

      my $packtodo = 0;
      my @big = ();
      my @small = ();

      if ( $opts{packing} and @upd > $opts{packmin} ) {
        my $m = 1048576;
        for ( @upd ) {
          my ( $path, $item ) = split /\s+/o, $_;
          my $size = -d $item ? 0 : -s $item;
          if ( $size / $m > $opts{packbig} ) {
            push @big, $_;
          } else {
            push @small, $item;
          }
        }
        if ( @small > $opts{packmin} and defined $opts{rpath} ) {
          $sh->tar( 'cf', "$opts{depot}/mtool.packing.$opts{tag}.tar", @small );
          @upd = @big;
          $packtodo = 1;
        }
      }

      open BCAST, ">>$opts{bcast}";
      print BCAST map { "$_\n" } @upd;
      close BCAST;

      if ( not $opts{delay} and defined $opts{rpath} ) {
        my $import =  new Mtool::Bin::Import;
        $import->process( %opts, -type => $type, -trackfile => $opts{bcast} )
      }

      if ( $packtodo ) {
        open BCAST, ">>$opts{bcast}";
        print BCAST "$opts{depot} mtool.packing.$opts{tag}.tar\n";
        close BCAST;
      }

    } else {
      $sh->rm( $opts{bcast} ) if -f $opts{bcast};
    }
  } else {
    sleep 1 if ( $type eq 'fs' );
  }

}

