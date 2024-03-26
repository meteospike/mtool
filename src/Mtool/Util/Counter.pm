package Mtool::Util::Counter;

use strict;
use base qw( Mtool::Util );

use Mtool::Util::Storable;


sub plus {
  my $class = shift;
  my %args = $class->opt2hash( @_ );

  my $item = delete $args{item};
  my $counter = new Mtool::Util::Storable( %args, -file => 'counter' );

  my $next = $counter->value( $item ) + 1;
  $counter->value( $item, $next );
  $counter->close();

  return $next;
}

sub value {
  my $class = shift;
  my %args = $class->opt2hash( @_ );

  my $item = delete $args{item};
  my $counter = new Mtool::Util::Storable( %args, -file => '<counter' );

  return $counter->value( $item );
}

1;
