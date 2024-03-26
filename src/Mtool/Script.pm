package Mtool::Script;

use strict;
use base qw( Mtool::Kit );

sub new {
  my $class = shift;

  my %args = (
    language => 'sh',
    indent => '',
    $class->opt2hash( @_ ),
  );

  my $coding_language = ucfirst( lc( $args{language} ) );

  eval "use Mtool::Script::$coding_language";
  Mtool->fatal( "no scripter module for $coding_language [$@]" ) if ( $@ ); 

  return bless \%args, "Mtool::Script::$coding_language";
}

1;

