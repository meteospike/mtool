package Mtool::Util::Storable;

use strict;
use base qw( Mtool::Util );

use Mtool::Shell;
use Mtool::Exception;

use Storable qw( retrieve store );
use FileHandle;
use Fcntl qw(SEEK_SET F_WRLCK F_UNLCK F_SETLKW :flock);


sub new {
  my $class = shift;
  my %args = (
    file  => 'undef',
    store => "$ENV{MTOOL_RC}/sto",
    lockstyle => 'flock',
    $class->opt2hash( @_ ),
  );

  unless ( defined $args{file} ) {
    my $e = new Mtool::Exception( -why => "storable filehandle not provided\n" );
    die "$e";
  }

  my $sh = new Mtool::Shell( -tag => 'mtoolkit' );
  $sh->mkdir( '-p', $args{store} ) unless ( -d "$args{store}" );

  $args{file} =~ s/^>//;
   $args{readonly} = $args{file} =~ s/^<//;

  $args{file} = join '/', $args{store}, $args{file};
  my $fh = $args{file};

  my $lock = undef;

  do {
    $lock = new FileHandle "$fh.lock", "w"
      or die new Mtool::Exception( -why => "could not get a file handle on $fh.lock: $!");
    if ($args{lockstyle} eq 'flock') {
      flock($lock, LOCK_EX) or die new Mtool::Exception( -why => "flock: $!" );
    } elsif ($args{lockstyle} eq 'fcntl') {
      #! this is not at all portable: see man 2 fcntl for a descrition of the flock C structure
      my $pack = pack('s s l l i', F_WRLCK, SEEK_SET, 0, 1, 0);
      fcntl($lock, F_SETLKW, $pack) or die new Mtool::Exception( -why => "fcntl: $!" );
    } else {
      die new Mtool::Exception( -why => "Unknown lockstyle: $args{lockstyle}" );
    }
  } unless  $args{readonly};

  my $h = ( -f "$fh.db" ) ? retrieve "$fh.db" : {};

  return bless {
    %args,
    file => "$fh.db",
    lock => $lock,
    hash => $h,
    mods => 0,
  }, $class;  
}

sub readonly {
  my ( $self ) = @_;
  return $self->{readonly};
}

sub rootvalue {
  my ( $self ) = @_;
  return $self->{hash};
}

sub entries {
  my ( $self ) = @_;
  return keys %{ $self->{hash} };
}

sub value {
  my ( $self, $key, $value ) = @_;

  if (defined $value && ! $self->readonly()) {
    $self->{hash}{$key} = $value;
    $self->{mods}++;
  }

  return exists $self->{hash}{$key} ? $self->{hash}{$key} : undef;
}

sub close {
  my ($self) = @_;

  return 1 if $self->readonly();

  store $self->{hash}, $self->{file} if $self->{mods};

    if ($self->{lockstyle} eq 'flock') {
      flock($self->{lock}, LOCK_UN);
    } elsif ($self->{lockstyle} eq 'fcntl') {
      #! this is not at all portable: see man 2 fcntl for a descrition of the flock C structure
      my $pack = pack('s s l l s', F_UNLCK, SEEK_SET, 0, 1, 0);
      fcntl($self->{lock}, F_SETLKW, $pack);
    }
  $self->{lock}->close();
  $self->{lock} = undef;
}

sub DESTROY {
  my ($self) = @_;
  $self->close() if $self->{'lock'};
}

1;

