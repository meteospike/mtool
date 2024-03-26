#!/usr/bin/perl -w 

use strict;

use FindBin qw ($Bin);
use lib "$Bin/../src";

use Mtool;
use Mtool::Shell;
use Getopt::Long;
use Sys::Hostname qw();

my $name   = 'submit';

my %opts = (
  depot    => $ENV{MTOOL_STEP_DEPOT},
  public   => $ENV{MTOOL_STEP_PUBLIC},
  step     => undef,
  job      => undef,
  output   => undef,
  tool     => 'sbatch',
  trace    => 1,
);

GetOptions(
  \%opts,
  qw( step=i job=s depot|path=s public=s tool|qsub=s output=s trace! )
) or die "usage: $name --step=step-number [--depot=path-name] [--public=path-name] [--output=output-file] [--tool=submit-method]\n";

Mtool->fatal( "$name: no step nor job defined" )
  unless ( defined $opts{step} or defined $opts{job} );

Mtool->fatal( "$name: no path to depot defined" )
  unless defined $opts{depot};

Mtool->fatal( "$name: no such path or directory [$opts{depot}]" )
  unless ( -d "$opts{depot}" );

Mtool->fatal( "$name: no path to public tools defined" )
  unless defined $opts{public};

Mtool->fatal( "$name: no such path or directory [$opts{public}]" )
  unless ( -d "$opts{public}" );

if ( defined $ENV{MTOOL_SUBMIT_SKIP} and $ENV{MTOOL_SUBMIT_SKIP} =~ /on/io ) {
  Mtool->info( "skip next step" );
  exit(0);
}

my $job =  $opts{job} || sprintf "$opts{depot}/step.%02d", $opts{step};

$opts{output} ||= "$job.out";

my $sh = new Mtool::Shell;
$sh->set( '-x' ) if delete $opts{trace};

for ( $opts{tool} ) {
  /qsub/io and do {
    my @cmd = ( 'qsub', '-o', $opts{output}, $job );
    if ( defined $ENV{MTOOL_NEST_USER} and $ENV{MTOOL_NEST_USER} ne $ENV{LOGNAME} ) {
      my $rhost = &Sys::Hostname::hostname();
      unshift @cmd, 'rsh', $rhost, '-l', $ENV{MTOOL_NEST_USER};
    }
    $sh->spawn( @cmd );
    next;
  };
  /sbatch|slurm/io and do {
    my @cmd = ( 'sbatch', '-o', $opts{output}, '-e', $opts{output}, $job );
    $sh->spawn( @cmd );
    next;
  };
  /filter/io and do {
    my @cmd = ( 'mtool_filter.pl', $job );
    $sh->spawn( @cmd );
    next;
  };
  /llsubmit/io and do {
    my @cmd = ( 'llsubmit', $job );
    $sh->spawn( @cmd );
    next;
  };
  /xspawn/io and do {
    my @cmd = ( $job );
    my $jobmode = 0755;
    chmod $jobmode, $job;
    open(my $oldout, ">&STDOUT") or die "Can't dup STDOUT: $!";
    open(my $olderr, ">&STDERR") or die "Can't dup STDERR: $!";
    open(STDOUT, '>', $opts{output}) or die "Can't redirect STDOUT: $!";
    open(STDERR, ">&STDOUT") or die "Can't dup STDOUT: $!";
    select STDERR; $| = 1;  # make unbuffered
    select STDOUT; $| = 1;  # make unbuffered
    $sh->spawn( @cmd );
    open(STDOUT, ">&", $oldout) or die "Can't dup \$oldout: $!";
    open(STDERR, ">&", $olderr) or die "Can't dup \$olderr: $!";
    next;
  };

  chmod 0755, $job;
  $sh->spawn( $_, $job );
}

exit(0)
