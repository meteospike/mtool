#!/usr/bin/perl -w 

use strict;

use FindBin qw ($Bin);
use lib "$Bin/../src";

use Mtool;
use Mtool::Bin::Fsync;
use Getopt::Long;
use Sys::Hostname qw();

my %opts = (
  depot    => $ENV{MTOOL_STEP_DEPOT} || $ENV{PWD},
  nodes    => $ENV{_MPILNODELIST},
  root     => &Sys::Hostname::hostname(),
  path     => undef,
  included => undef,
  excluded => '*.tar,*.tgz',
  debug    => 0,
  trace    => 1,
  gather   => 0,
  force    => 0,
  split    => 0,
  verbose  => 0,
);

GetOptions(
  \%opts,
  qw( depot=s path=s nodes=s included=s excluded=s debug=i root=s mpirun=s gather! force! split! trace! verbose! )
) or die "usage: mtool_fsync.pl\n  [--depot=depot-path]\n  [--path=path-to-sync]\n  [--root=node-root]\n  [--nodes=list-of-nodes]\n  [--included=motif-to-sync]\n  [--excluded=motif-not-to-sync]\n  [--mpirun=mpi-launch-cmd]\n  [--[no]gather]\n  [--[no]force]\n  [--[no]verbose]\n  [--[no]debug]\n  [--[no]split]\n  [--[no]trace]\n";

Mtool->fatal( "$opts{depot}: no such directory" ) unless ( -d "$opts{depot}" );

Mtool->fatal( "$opts{path}: no such directory" ) unless ( -d "$opts{path}" );

my $fs = new Mtool::Bin::Fsync;

$fs->process( %opts );

