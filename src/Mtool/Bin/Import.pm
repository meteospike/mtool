package Mtool::Bin::Import;

use strict;

use Mtool;
use base qw( Mtool::Bin );

use Data::Dumper qw( Dumper );

sub env {
  my $self = shift;

  my %args = (
    $self->opt2hash( @_ ),
  );
}

sub fs {
  my $self = shift;

  my %args = (
    cpcmd  => $ENV{MTOOL_IMPORT_CMD} || 'cp',
    cpopts => $ENV{MTOOL_IMPORT_CMDOPTS} || '',
    trackfile => undef,
    $self->opt2hash( @_ ),
  );

  my $cmd = $args{cpcmd};
  my $brfile = $args{trackfile} || "$args{depot}/mtool.bcast.fs.$args{tag}";

  $self->shell->ls( '-l', $args{depot} ) if ( $args{verbose} );

  return unless ( -f $brfile );

  my $t0 = time();
  my %mkdone = ();

  $self->shell->cat( $brfile ) if ( $args{verbose} );

  open BCAST, "<$brfile"
    or $self->fatal( "could not open bcast file $brfile" );
  my @items = <BCAST>;
  close BCAST;

  my $local = $ENV{PWD};
  if ( defined $args{rpath} and -d $args{rpath} ) {
    chdir $args{rpath};
    $self->info( "chdir to $args{rpath}" );
    $local = $args{rpath};
  }

  my @cpopts = split /\s+/o, $args{cpopts};
  for ( @items ) {
    my ( $root, $subpath ) = split /\s+/o, $_;
    next if ( $root eq $local );
    if ( $subpath =~ /\//o ) {
      ( my $dir = $subpath ) =~ s/\/[^\/]+$//go;
      unless ( $mkdone{"$dir"} or -d $dir ) {
        mkdir $dir;
        $mkdone{"$dir"} = 1;
      }
    }
    if ( -d "$root/$subpath" ) {
      $self->shell->rm( '-rf', "$subpath" );
      $self->shell->$cmd( @cpopts, '-r', "$root/$subpath", "$subpath" );
    } else {
      $self->shell->$cmd( @cpopts, "$root/$subpath", "$subpath" );
    }
  }

  $self->shell->rm( $brfile );

  for ( <mtool.packing.*.tar> ) {
    $self->shell->tar( 'xfm', $_ );
    $self->shell->rm( $_ );
  }

  $self->info( sprintf "remote %d items took %d seconds", scalar( @items ), time() - $t0 );
}

sub process {
  my $self = shift;
  my %args = ( $self->opt2hash( @_ ) );
  my $type = lc( delete $args{type} );
  $self->$type( %args );
}

1;
