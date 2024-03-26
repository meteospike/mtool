package Mtool::Bin::Track;

use strict;

use Mtool;
use base qw( Mtool::Bin );

use Data::Dumper qw( Dumper );


sub env_dump {
  my ( $self, $file ) = @_;
  local $Data::Dumper::Terse = 1;
  local $Data::Dumper::Indent = 1;
  open TAGFILE, ">$file"
    or $self->fatal( "could not open $file" );
  print TAGFILE Dumper( \%ENV );
  close TAGFILE;
}

sub env {
  my $self = shift;

  my %args = (
    reset   => 0,
    verbose => 0,
    $self->opt2hash( @_ ),
  );

  my @tr = ();
  my $tf = $self->tagfile( %args, -type => 'env' );

  if ( not $args{reset} and -f $tf ) {
    my $old = do "$tf";
    for ( grep !/^(?:$args{discard})/, grep /^(?:$args{filter})/, keys %ENV ) {
      push @tr, "export $_=\"$ENV{$_}\"" if ( not defined $old->{$_} or $old->{$_} ne $ENV{$_} );
    }
    $self->info( map { "env $_" } @tr )
      if ( @tr and $args{verbose} );
  }

  $self->env_dump( $tf );
  return @tr;
}

sub fs {
  my $self = shift;

  my %args = (
    reset => 0,
    deep  => 1,
    $self->opt2hash( @_ ),
  );

  my @tr = ();
  my $tf = $self->tagfile( %args, -type => 'fs' );

  if ( not $args{reset} and -f $tf ) {
    my $stamp = -M "$tf";
    if ( $args{deep} ) {
      use File::Find;
      find {
        wanted => sub {
          push @tr, $File::Find::name if ( -f $_ and -M $_ < $stamp );
        },
        follow   => 0,
        no_chdir => 1,
      }, $args{root};
    } else {
      @tr = grep { ( -f $_ or -d $_ ) and -M $_ < $stamp } <$args{root}/*>;
    }

    open TF, "<$tf"
      or $self->fatal( "could not open tagfile $tf" );
    my %here = map { chomp; $_ => 1 } <TF>;
    close TF;

    for ( <*> ) {
      push @tr, $_ if not $here{$_};
    }

    @tr = grep !/(?:$args{discard})/, grep /(?:$args{filter})/, @tr;

    $self->info( map { "fs update $_" } @tr )
      if ( @tr and $args{verbose} );

    my %seen = ();
    @tr = grep { not $seen{$_}++ } map { s/$args{root}\///o; "$args{root} $_" } @tr;
  }

  open TF, ">$tf"
    or $self->fatal( "could not open tagfile $tf" );
  print TF map { "$_\n" } <*>;
  close TF;

  return @tr;
}

sub process {
  my $self = shift;
  my %args = ( $self->opt2hash( @_ ) );

  $args{$_} =~s /\s*,\s*/|/go for ( qw( filter discard ) );

  my $type = delete $args{type};
  $self->$type( %args );
}

1;
