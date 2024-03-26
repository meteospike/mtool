package Mtool::Script::Perl;

use strict;
use base qw( Mtool::Script );

use Safe;


sub setup {
}

sub export {
}

sub function {
}

sub evaluate {
  my ( $class, $code ) = @_;
  my $compartment = new Safe;
  $compartment->permit_only( qw( :default ) );
  $compartment->reval( $code );
}

1;

