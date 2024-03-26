package Mtool::Bin::Fsync;

use strict;

use Mtool;
use base qw( Mtool::Bin );

use Data::Dumper;

sub process {
  my $self = shift;

  my %args = (
    $self->opt2hash( @_ ),
  );

  my $conf = 'fsync.conf';

  $args{nodes} =~ s/^\s+//go;
  $args{nodes} =~ s/\s+$//go;

  my @nodes = grep { $_ ne $args{root} } map { s/^\d+://go; $_ } split /[\s,]+/, $args{nodes};
  my @syncpath =  ( $args{path}, map { "$_:$args{path}" } @nodes );

  unless ( @nodes ) {
    $self->trouble( "no extra node to sync with" );
    exit 0;
  }

  my @included = defined $args{included}
    ? map { ('-i', "$_") } split( /,/o, $args{included} )
    : ();
  my @excluded = defined $args{excluded}
    ? map { ('-e', "$_") } split( /,/o, $args{excluded} )
    : ();

  $self->shell->set( '-x' ) if delete $args{trace};

  if ( $args{verbose} and $args{debug} ) {
    $self->shell->ls( '-l' );
  }

  $self->shell->spawn( grep /\S/o,
    '/usr/local/bin/ixsync',
    $args{force} ? '-f' : '',
    $args{gather} ? '-g' : '-s',
    @syncpath,
    @included,
    @excluded,
    $args{verbose} ? ( '-v', '15' ) : ''
  );
}

1;
