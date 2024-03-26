package Mtool::Script::Python;

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

  return map {
   $indent . "os.environ\[\'" . uc( $_ ) . "\'\]=\"$args{$_}\"\n"
  } ( keys %args );
}

sub function {
  my ( $self, @args ) = @_;
  my %args = $self->opt2hash( @args );

  my $cmd = delete $args{cmd};

  my $indent = delete $args{indent};

  my $shcmd = join ' ',
    "$self->{prefix}$self->{filter}{root}/bin/mtool_$cmd.pl",
    map(
      {
        my ( $p, $v ) = ( '', "=$args{$_}" );
        $p = 'no' if ( $v eq '=off' );
        $v = '' if ( $v =~ /^=(?:on|off)$/o );
        "--$p$_$v"
      } ( keys %args )
    );

  return $indent . "os.system(\"$shcmd\")\n";
}

sub broadcast {
  my ( $self, @args ) = @_;
  my %args = $self->opt2hash( @args );

  my $indent = delete $args{indent};

  return map { "$indent$_"} (
    "mtool_bcast = open('$args{file}', 'a')\n",
    map( { 'mtool_bcast.write("' . uc($_) . '=" + str(e.' . $_ . ') + "\n")' . "\n" }  map { s/\"//go; $_ } split /,/o, $args{vars} ),
    "mtool_bcast.close()\n"
  );
}

1;

