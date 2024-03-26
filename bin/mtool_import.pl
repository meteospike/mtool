#!/usr/bin/perl -w 

use strict;

use FindBin qw ($Bin);
use lib "$Bin/../src";

use Mtool;
use Mtool::Shell;
use Mtool::Bin::Import;
use Getopt::Long;

my %opts = (
  depot     => $ENV{MTOOL_STEP_DEPOT} || $ENV{PWD},
  tag       => $ENV{MTOOL_STEP_ID} || 'misc',
  type      => undef,
  verbose   => 1,
  trace     => 1,
);

GetOptions(
  \%opts,
  qw( path|depot=s type=s tag=s verbose! trace! )
) or die "usage: mtool_import.pl\n  --tag=tag-name\n  --type=env-of-fs\n  [--depot=path-name]\n  [--[no]verbose]\n  [--[no]trace]\n";

Mtool->fatal( "$opts{depot}: no such directory" )
  unless ( -d "$opts{depot}" );

Mtool->fatal( "import: a type must be set" )
  unless ( defined $opts{type} );

my $sh = new Mtool::Shell( -tag => 'mtoolkit' );
$sh->set( '-x' ) if delete $opts{trace};

my $import = new Mtool::Bin::Import;

$import->process( %opts, -type => $_ )
  for ( split /,/, delete $opts{type} );

