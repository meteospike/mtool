package Mtool::Shell;

use strict;
use base qw( Mtool::Kit );

use Config qw();
use File::Path;

our $SHNAME = 'default';
our %SHTAGS = ();

sub new {
  my $class = shift;

  my $tmp = bless {
    tag   => undef,
    log   => [],
    flags => { qw( x + e + ) },
    cmds  => [ qw(
      mv cp rm ln timex simplemkdir mkdir cat ls spawn gget ksh touch rcp tail gzip gunzip echo
      tar cd export unset remsh gzip rmdir uncompress which ftget ftput
    ) ],
    dels  => [],
    adds  => [],
    $class->opt2hash( @_ ),
  }, $class;

  my $self = $tmp;

  if ( defined $tmp->{tag} ) {
    $self = $SHTAGS{$tmp->{tag}} if exists $SHTAGS{$tmp->{tag}};
  } else {
    $tmp->{tag} = $SHNAME
  }

  $SHTAGS{$tmp->{tag}} = $self;

  $self->adds( @{ $tmp->{adds} } );
  $self->dels( @{ $tmp->{dels} } );
  
  return $self;
}

sub shell {
  return undef;
}

sub default {
  my $class = shift;
  $SHNAME = shift if @_;
  return $SHNAME;
}

sub adds {
  my ( $self, @args ) = @_;
  my %seen = ();
  $self->{cmds} = [
    grep { not $seen{$_}++ }
    @{$self->{cmds}}, @args
  ];
  return sort @{$self->{cmds}};
}

sub dels {
  my ( $self, @args ) = @_;
  my %seen = map { $_ => 1 } @args;
  $self->{cmds} = [ grep { not exists $seen{$_} } @{$self->{cmds}} ];
  return sort @{$self->{cmds}};
}

sub set {
  my ( $self, @args ) = @_;
  for ( @args ) { 
    my @t = split //;
    my $u = shift @t;
    $self->{flags}{$_} = $u for( @t );
  };
}

sub flags {
  my ( $self ) = @_;
  return ( sort grep { $self->{flags}{$_} eq '-' } keys %{ $self->{flags} } );
}

sub switch {
  my ( $self, $var ) = @_;
  $var = uc( $var );
  return ( defined $ENV{$var} ) ? $ENV{$var} !~ /^(?:off|no|ko|0)$/io : 0;
}

sub log {
  my ( $self ) = @_;
  print " > $_\n", for ( @{ $self->{log} } );
}

sub batch_context {
  return (exists $ENV{QSUB_REQID} or exists $ENV{LOADL_PID});
}

sub internal_process {
  my ( $self, $cmd, @args ) = @_;

  my $rc = $self->internal_execute( $cmd, @args );

  if ( $self->{flags}{e} eq '-' ) {
    {
      local $" = ', ';
      my ( $package, $filename, $line ) = caller;
      $self->fatal( $package, $line, "$cmd( @args ) failed : $!" )
        unless $rc;
    }
  };

  return $rc;
}

sub internal_execute {
  my $self = shift;

  my ( $rc, $sn, $dc );

  my @cmd = grep { defined $_ and /\S/ } @_;

  if ( system( @cmd ) == -1 ) {
    return 0;
  } else {
    $rc = $? >> 8;    # exit value
    $sn = $? & 127;   # signal number
    $dc = $? & 128;   # coredump
  }

  if ( ( $self->{flags}{x} eq '-' ) or ( $self->{flags}{e} eq '-' ) ) {
    if ( $rc ) {
      $self->trouble( "'@_' exited with status $rc" );
    }
    if ( $dc ) {
      $self->trouble( "'@_' dumped core with return code $rc" );
      $rc = 1;
    };
    if ( $sn ) {
      my @sig;
      my @n = split( m/\s+/o, $Config::Config{sig_name} );
      my $i = 0;
      for ( split /\s+/o, $Config::Config{sig_num} ) {
        $sig[$_] = $n[$i++];
      }
      $self->trouble( "'@_' got a $sig[$sn] signal with return code $rc" );
      $rc = 1;
    };
  }

  return ! $rc;
}

sub _rm {
  my $self = shift;
  if( $_[0] =~ /^-/ ) {
    $self->internal_process( 'rm', @_ );
  } else {
    unlink @_;
  }
}

sub _ln {
  my $self = shift;
  if ( $_[0] =~ /^-s$/ ) {
     symlink( $_[1],  $_[2] );
  } else {
     link $_[0], $_[1];
  }
}

sub _simplemkdir {
  my $self = shift;
  mkdir( $_[0] );
}

sub _mkdir {
  my $self = shift;
  shift( @_ ) while( $_[0] =~ /^-/o );
  mkpath( [ @_ ], ( $self->{flags}{x} ne '-' ), 0755 );
}

sub _cat {
  my $self = shift;
  if( grep { /<|>/ } @_ ) {
    $self->internal_process( "cat @_" );
  } else {
    $self->internal_process( "cat", @_ );
  }
}

sub _which {
  my $self = shift;
  $self->internal_process( 'which', $_ ) for ( @_ );
}

sub _rcp {
  my $self = shift;
  if ( $self->batch_context() ) {
    ( my $node = qx( uname -n ) ) =~ s/(?<=[cx]bar).+\n*/00/o;
    $self->internal_process( 'remsh', $node, "cd $ENV{PWD}; rcp @_" );
  } else {
    $self->internal_process( 'rcp', @_ );
  }
}

sub _tar {
  my ( $self, $opts, @args ) = @_;
  $opts .= 'o'
    if ( $opts =~ /x/o and defined $ENV{PBS_JOBID} and $ENV{PBS_JOBID} =~ /dana/o );
  $self->internal_process( 'tar', $opts, @args );
}

sub _cd {
  my $self = shift;
  chdir( $_[0] );
}

sub _pwd {
  use Cwd qw( cwd );
  return cwd;
}

sub _export {
  my ( $self, $name, $value ) = @_;
  $ENV{$name} = $value;
}

sub _unset {
  my ( $self, $name, $value ) = @_;
  delete $ENV{$name};
}

sub _remsh {
  my $self = shift;
  ( -f '/usr/bin/remsh' ) && return $self->internal_process( 'remsh', @_ );
  ( -f '/usr/bin/rsh' )   && return $self->internal_process( 'rsh', @_ );
}

sub _hostname {
  require Sys::Hostname;
  return &Sys::Hostname::hostname();
}

sub _gunzip {
  my $self = shift;
  my @gzip =  ( defined $ENV{PBS_JOBID} and $ENV{PBS_JOBID} =~ /dana/o )
    ? ( 'gzip', '-d' )
    : ( 'gunzip' );
  $self->internal_process( @gzip, @_ );
}

sub _echo {
  my $self = shift;
  print join( ' ', @_ ), "\n";
}

sub _env {
  my $self = shift;
  if ( $self->{flags}{x} eq '-' ) {
    {
      local $" = ', ';
      my ( $package, $filename, $line ) = caller;
      $self->trace( $package, $line, "env @_" );
    }
  };
  $self->info( map { sprintf "%-20s = %s", $_, $ENV{$_} } ( sort keys %ENV ) );
}

sub _spawn {
  my $self = shift;
  return $self->internal_process( @_ );
}

sub AUTOLOAD {
  my ( $self, @args ) = @_;

  ( my $method = our $AUTOLOAD ) =~ s/.*:://o;
  return if ( $method eq 'DESTROY' );

  $method = lc( $method );
  $self->fatal( "$method is not a valid shell command" )
    unless ( grep { $method eq $_ } @{ $self->{cmds} } );

  if ( $self->{flags}{x} eq '-' ) {
    { 
      local $" = ', ';
      my @a = @args;
      my ( $package, $filename, $line ) = caller;
      $self->trace( $package, $line, "$method @a" );
    }
  };

  { 
    local $" = ', ';
    push @{ $self->{log} }, "$method( @args )";
  }

  my $internal = "_$method";

  return $self->can( $internal )
    ? $self->$internal( @args )
    : $self->internal_process( $method, @args );
}

1;
