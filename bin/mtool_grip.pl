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
  doneflag => 1,
  old      => 5. / 86400,
  timeout  => 20,
  retry    => 1,
  trace    => 1,
  verbose  => 1,
);

my @files = ();

GetOptions(
  \%opts,
  '<>' => sub { push @files, @_ },
  qw( path=s timeout=i retry=i old=s doneflag! trace! verbose! )
) or die "usage: mtool_grip.pl [--path=path-name] [--timeout=seconds] [--old=timeindays] [--retry=seconds] [--[no]doneflag] [--[no]trace]  [--[no]verbose]\n";

Mtool->fatal( "grip: no such directory ( $opts{path} )" )
  if ( defined $opts{path} and not -d $opts{path} );

chdir $opts{path} if defined $opts{path};

my $sh = new Mtool::Shell;
$sh->set( '-x' ) if delete $opts{trace};

my %complete = ();
my @missing = ();
my %done = ();

while ( @files ) {
  my $patience = $opts{timeout};
  for ( shift @files ) {
    $done{$_} ||= 0;
    $complete{$_} ||= 0;
    /\.done$/ and do {
      ( my $fout = $_ ) =~ s/done$/out/o;
      push @files, $fout;
      while ( not -f $fout and $patience >= 0 ) {
	sleep $opts{retry};
        $patience -= $opts{retry};
      }
      if ( $patience < 0 ) {
        push @missing, $fout;
      } else {
        $done{$fout} = 1;
      }
      next;
    };
    /\.out$/ and not -f $_ and $opts{doneflag} and do {
      push @missing, $_;
      next;
    };
    /\.out$/ and not $complete{$_} and ( not $opts{doneflag} or $done{$_} ) and do {
      $complete{$_} = 1;
      my $fout = $_;
      my $s = -s $fout;
      my $grow = 1;
      while ( -M $fout < $opts{old} and $grow > 0 and $patience >= 0 ) {
        sleep $opts{retry};
        $patience -= $opts{retry};
        $grow = -s $fout;
        ( $grow, $s ) = ( $grow - $s, $grow );
      }
      push @missing, $fout if ( $patience < 0 );
      next;
    };
  }
}

print STDERR "grip: missing $_\n" for @missing;

print join( ' ', sort grep { $complete{$_} == 1 } keys %complete ), "\n";

