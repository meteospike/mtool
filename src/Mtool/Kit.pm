package Mtool::Kit;

use strict;
use Mtool::Shell;

sub new {
  my $class = shift;
  return bless { _shell => undef, @_ }, $class;
}

sub shell {
  my $self = shift;
  $self->{_shell} ||= new Mtool::Shell( -tag => 'mtoolkit', @_ );
  return $self->{_shell};
}

sub rmall {
  my ( $class, %args ) = @_;

  my $self = delete $args{-object} || $class;

  return unless ( exists $args{-path} and -d "$args{-path}" );

  my $sh = $self->shell();

  $self->info( join ' ', 'cleaning on', uc( $args{-error} ), 'error' )
    if ( $args{-error} );

  for ( <$args{-path}/*> ) {
    ( -d $_ and 0 ) and do {
      $sh->rm( '-rf' , $_ );
      next;
    };
    ( -f $_ ) and do {
      $sh->rm( $_ );
      next;
    };
  }

  $sh->rmdir( $args{-path} );
}

sub opt2hash {
  my ( $class, @args ) = @_;

  my %args = ();

  while ( my ( $k, $v ) = splice( @args, 0, 2 ) ) {
    $k =~ s/^\-+//go;
    $args{$k} = $v;
  }

  return %args;
}

1;
