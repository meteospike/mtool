#!/usr/bin/perl -w 

use strict;

use FindBin qw ($Bin);
use lib "$Bin/../src";
use File::Basename qw( dirname );

use Mtool;
use Mtool::Filter;

use Getopt::Long;

my @jobs = ();
my %args = (
  root   => dirname( $Bin ),
  submit => 1,
  subshell => 0,
);

my @opts = qw(
    host=s
    frontend=s
    cpunodes=s
    user=s
    language=s
    languagext=s
    subshell!
    verbose!
    root=s
    mtoolrc=s
    incpath=s
    ftdir=s
    mtooldir=s
    tmploc=s
    tmpdir=s
    workdir=s
    depotroot=s
    cacheroot=s
    abortroot=s
    spoolroot=s
    spool=s
    node=s
    shell=s
    export=s
    stdin!
    submit!
    proftag=s
    jobname=s
    jobtag=s
    notdefault=s
    logfile=s
    logtarget=s
    autolog=s
    autoclean=s
    cleanmode=s
    submitcmd0=s
    submitcmd=s
    submitmethod=s
    inclprompt=s
    nest=s
    id=s
    time!
    timer=s
    set=s@
    lockstyle=s
);

GetOptions(
  \%args,
  '<>' => sub { push @jobs, @_ },
  @opts,
) or die "usage: mtool_filter.pl [--option=value] job-file1 [job-file2]...\n";

if ( defined $args{stdin} ) {
  die "-stdin cannot be mixed with job-file specifications\n" if @jobs;
}

if ( defined $args{set} ) {
  $args{setvars} = join ',', map { s/\s+$//go; s/^\s+//go; $_ } @{ delete $args{set} };
}

if ( defined $args{stdin} ) {
    my $jf = new Mtool::Filter( %args, -stdin => 1);
    $jf->process();
} else {
    for my $file ( @jobs ) {
      my $jf = new Mtool::Filter( %args, -job => $file );
      $jf->process();
    }
}

exit(0)
