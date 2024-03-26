#!/usr/bin/perl -w 

use strict;

use FindBin qw ($Bin);
use lib "$Bin/../src";

use Mtool;
use Mtool::Shell;

my $sh = new Mtool::Shell ( -dels => [ qw( ls ) ] );
print "> this is $sh\n";

$sh->set( '-x' );

$sh->adds( qw( ll ) );


$sh->ll();
$sh->cat( 'mtool_test.pl' );
$sh->echo( qw( fini les aminches ) );

sub bidon {
  my $bof = new Mtool::Shell( -tag => 'default' );
  print "this is $bof\n";
  $bof->echo( qw( bidon ) );
}

&bidon();

$sh->log();

exit 0;

package Mtool::Shell;

sub _ll {
  my $self = shift;
  $self->internal_process( qw( ls -l ), @_ );
}

1;
