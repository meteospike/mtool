package Mtool::Bin;

use strict;
use base qw( Mtool::Kit );

sub tagfile {
  my $self = shift;
  my %args = $self->opt2hash( @_ );
  ( my $kind = ref( $self ) ) =~ s/.*:://og;
  return "$args{depot}/mtool.\L$kind.$args{type}.$args{tag}";
}


1;

