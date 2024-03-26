package Mtool;

use strict;

our $VERSION = '2.3.5';

use Mtool::Exception;


sub UNIVERSAL::info : method {
  my ( $self, @lines ) = @_;
  my $prompt = ref( $self ) || $self;
  print STDERR map { "[$prompt][info] $_\n" } @lines;
}

sub UNIVERSAL::trouble : method {
  my ( $self, @lines ) = @_;
  my $prompt = ref( $self ) || $self;
  print STDERR map { "[$prompt][trouble] $_\n" } @lines;
}

sub UNIVERSAL::trace : method {
  my ( $self, $package, $num, $command ) = @_;
  printf STDERR "[$package][line:%d] $command\n", $num;
}

sub UNIVERSAL::fatal : method {
  my ( $self, $msg ) = @_;

  if ( ref( $self ) and $self->{on_error} ) {
    $self->rmall( -error => 'fatal', -path => $_ )
      for ( @{ $self->{on_error} } );
  }

  my $e = new Mtool::Exception( -why => $msg );
  die "$e";
}

1;
