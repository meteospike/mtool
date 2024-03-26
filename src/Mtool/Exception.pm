package Mtool::Exception;

use strict;
use overload '""' => 'as_string';

use Data::Dumper;

sub new {
  my $class = shift;

  my $i = 0;
  my @stack = ();

  while ( 1 ) {
    my ( $package, $filename, $line, $subroutine ) = caller( $i );
    last unless $filename;
    push @stack, { 
      -package    => $package,
      -filename   => $filename,
      -line	  => $line,
      -subroutine => $subroutine,
    };
    $i++;
  }

  return bless { @_, -stack => \@stack }, $class;
}

sub message {
  my ( $self ) = @_;
  return '<ABORT> ' . ( $self->{-why} || '' );
}

sub stack_as_string {
  my ( $self ) = @_;
  return map {
    ( defined $_->{'-subroutine'} and defined $_->{'-line'} )
      ? sprintf "<TRACE> called by %-30s at line %6d", $_->{'-subroutine'}, $_->{'-line'}
      : "$_"
  } grep { defined $_ } @{$self->{-stack}};
}

sub as_string {
  my ( $self ) = @_;
  return join "\n",
    $self->message(),
    $self->stack_as_string(),
    '';
}

1;
