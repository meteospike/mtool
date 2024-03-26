package Mtool::Script::Ksh;

use strict;
use base qw( Mtool::Script );


sub setup {
  my ( $self, @args ) = @_;
  my %args = $self->opt2hash( @args );
  $self->{prefix} = $args{time} ? "$args{timer} " : '';
}

sub export {
  my ( $self, @args ) = @_;
  my %args = $self->opt2hash( @args );

  my $indent = delete $args{indent};

  my $autox = ( $self->{filter}{export} =~ /^(?:all|on)/io ) ? "$indent" : $indent . 'export ';

  return map {
    $autox . uc( $_ ) . "=\"$args{$_}\"\n"
  } ( keys %args );
}

sub function {
  my ( $self, @args ) = @_;
  my %args = $self->opt2hash( @args );

  my $indent = delete $args{indent};
  my $cmd = delete $args{cmd};

  return join ' ',
    "$indent$self->{prefix}$self->{filter}{root}/bin/mtool_$cmd.pl",
    map(
      {
        my ( $p, $v ) = ( '', "=$args{$_}" );
        $p = 'no' if ( $v eq '=off' );
        $v = '' if ( $v =~ /^=(?:on|off)$/o );
        "--$p$_$v"
      } ( keys %args )
    ), "\n";
}

sub broadcast {
  my ( $self, @args ) = @_;
  my %args = $self->opt2hash( @args );

  my $indent = delete $args{indent};
  my $autox = ( $self->{filter}{export} =~ /^(?:all|on)/io ) ? '' : 'export ';

  return map { "$indent$_" } (
    "cat <<EOBCAST >> $args{file}\n",
    map( {  $autox . "$_=\"\$$_\"\n" }  map { s/\"//go; $_ } split /,/o, $args{vars} ),
    "EOBCAST\n"
  );
}

1;

