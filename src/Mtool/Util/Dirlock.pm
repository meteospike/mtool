package Mtool::Util::Dirlock;

use strict;

use base qw( Mtool::Util );

use Mtool::Exception;
use File::stat;

sub new {
  my $class = shift;
  my %args = (
    file  => undef,
    maxlockage => 7200,
    $class->opt2hash( @_ ),
  );

  unless ( defined $args{file} ) {
    my $e = new Mtool::Exception( -why => "Lock directory name was not provided\n" );
    die "$e";
  };
  return bless {
    %args,
    _shell => undef,
    _locked => 0,
  }, $class;
}

sub lock {
  my ($self) = @_;
  my $sh = $self->shell;
  $self->{_locked} = scalar($sh->simplemkdir($self->{file}));

  if ($self->{_locked}) {
    $self->info( "Directory lock ($self->{file}) acquired." );
  } else {
    if (my $st = stat($self->{file})) {
      my $lock_age = time() - $st->ctime;
      $self->info( "Unable to create the lock directory. The current one is $lock_age seconds old." );
      if ($lock_age > $self->{maxlockage}) {
        $self->trouble( "The lock directory is out of date... cleaning up this mess !" );
        $self->free();
      }
    } else {
      $self->info( "Unable to create the lock directory. But it disappeared in the meantime !" );
    }
  }
  return $self->{_locked};
}

sub free {
  my ($self) = @_;
  my $sh = $self->shell;

  if (not $sh->rmdir($self->{file})) {
    $self->trouble("rmdir failed on $self->{file}... Trying rmtree");
    $sh->rm('-rf', $self->{file}) or Mtool->trouble("rm -rf failed on $self->{file}...");
  }
  $self->{_locked} = 0;
}

sub DESTROY {
  my ($self) = @_;
  $self->free() if $self->{_locked};
}

1;
