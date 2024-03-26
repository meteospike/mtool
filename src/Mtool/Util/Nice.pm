package Mtool::Util::Nice;

use strict;
use Mtool;
use base qw( Mtool::Util );

use Data::Dumper;

sub dump {
  my $class = shift;
  local $Data::Dumper::Indent = 1;
  local $Data::Dumper::Terse  = 1;
  return Dumper( @_ );
}

1;
