#!/usr/bin/perl -w 

use strict;

use FindBin qw ($Bin);
use lib "$Bin/../src";

use Mtool;
use Mtool::Shell;
use Mtool::Util::Dirlock;

use File::Find;
use File::Path qw/ make_path /;
use Getopt::Long;
use Time::HiRes qw/ usleep /;

my $rmopts = '-rf';

my %fbytes = (
  k => 1,
  m => 1024,
  g => 1024 * 1024,
  t => 1024 * 1024 * 1024,
);

my %opts = (
  path          => undef,       # - The path were the clean will take place
  old           => 15,          # - Items older than "old" days will be deleted
  max           => 999,         # - Maximum number of items that will be deleted
  size          => undef,       # - Maximum total size of "path". Items newer than
                                #   "old" may be deleted to achieve this goal
  lfs           => 0,           # - Use the Lustre specific command whenever possible
  crude         => 0,           # - Perform a usual "find" instead of the
                                #   Olive/Vortex specific cleaning
  recurse       => 0,           # - Check all the files inside an Olive directory
                                #   (not recommanded because it's costfull)
  id            => 'default',   # - Nickname of this cleaning process (will be
                                #   used to generate the stamp file in ~/tmp)
  mksizedelay   => 36000,       # - Delay between "du" or "find" (stamp file are
                                #   used to ensure this delay). In seconds.
  startuprandom => 0,           # - Introduce a Ns random sleep at startup. In seconds.
  remove        => 1,           # - Actually remove the selected items
  trace         => 1,           # - Like set -x in bsh shells
  verbose       => 1,           # - Be talkative
  rmmaxtime     => 0,           # - Stop erasing files after XXsec of elapsed time
  maxlockage    => 7200,        # - The maximum age for a lock directory
);

GetOptions(
  \%opts,
  qw( path=s old|days=i max=i size=s lfs! crude! recurse! id=s mksizedelay=i startuprandom=i
      trace! remove! verbose! rmmaxtime=i maxlockage=i )
) or die "usage: mtool_clean.pl --path=path-name [--old=number-of-days] ".
            "[--max=nb-max-remove] [--size=max-size] [--id=cleaner-name] ".
            "[--mksizedelay=NNNNs] [--startuprandom=NNNNs] [--rmmaxtime=NNNNs] ".
            "[--maxlockage=NNNNs] [--[no]crude] [--[no]lfs] [--[no]recurse] ".
            "[--[no]trace] [--[no]remove] [--[no]verbose]\n";

Mtool->fatal( "clean: path not defined" )
  unless ( defined $opts{path} );

Mtool->fatal( "clean: too dangerous root path" )
  if ( $opts{path} =~ /\.\./ or "$opts{path}" eq "$ENV{HOME}" );

my $sh = new Mtool::Shell;
$sh->set( '-x' ) if delete $opts{trace};

my $mksize = 0;
if ( defined $opts{size} and $opts{size} =~ s/([\D])[ob]?$//i ) {
  Mtool->fatal( "clean: unkown unit size $1" )
    unless ( exists $fbytes{$1} );
  $opts{size} = $opts{size} * $fbytes{$1};
  $mksize = 1;
}

Mtool->fatal( "--crude and --size cannot be used at the same time" )
  if ( $opts{crude} and $mksize );

if (! ( -d "$opts{path}" or $opts{path} =~ /[\?\*]/ )) {
    Mtool->info( "$opts{path}: no such directory. Nothing to clean..." );
    exit 0;
}

Mtool->info( "Starting mtool_clean for $opts{path}" );

# --------------------------------------------------------------------------

# Random wait on startup.
# NB: If several cleaning job are lauched at the same time (ensemble
#     configuration for example), it may help to have a small random
#     delay at startup.
if ( $opts{startuprandom} > 0 ) {
  my $rsleep = int(rand($opts{startuprandom} * 1000000));
  Mtool->info( "This is a small random sleep (" . $rsleep .
               "µs / max: " . $opts{startuprandom} . "s)");
  Time::HiRes::usleep($rsleep);
}

# --------------------------------------------------------------------------

# Create the tmp directory (if missing)
make_path("$ENV{HOME}/tmp");
# Fake lock system: tries to create a directory... if it fails someone else 
# is already doing the job
my $fakelock = Mtool::Util::Dirlock->new( -file => "$ENV{HOME}/tmp/mtool.cleanlock.$opts{id}",
                                          -maxlockage => $opts{maxlockage} );
exit 0 unless $fakelock->lock();

sub lock_cleaner_handler {
  my($sig) = @_;
  $fakelock->free();
  die "Caught a SIG$sig -- lock directory was cleaned up.\n";
}
use sigtrap 'handler', \&lock_cleaner_handler, 'normal-signals';

# --------------------------------------------------------------------------

# We check the date of the stamp file...
my $stampcheck = 0;
# Check the timestamps only if needed...
if ($opts{crude} or $mksize) {
	my $curstamp = time();
  my @stamps = <$ENV{HOME}/tmp/mtool.cleanstamp.$opts{id}.*>;
  $stampcheck = 1;
  for my $stamp ( @stamps ) {
    if (my ($epoch,) = ($stamp =~ m/\.(\d+)$/)) {
      $epoch = int($epoch);
      $stampcheck &&= ($epoch < $curstamp - $opts{mksizedelay} or
  		     $epoch > $curstamp + 300);
    }
  }
  if ( $stampcheck ) {
    # Create a new stamp file ans remove the old one.
    # NB: A random offset is added (5% of the mksizedelay). That way, the cleaning
    # scripts of the various users should be spread all over time.
    my $rdelay = int(rand($opts{mksizedelay}) * 0.05);
    Mtool->info( "Current time stamp is $curstamp. Random delay added $rdelay.")
    if ( $opts{verbose} );
    $sh->touch("$ENV{HOME}/tmp/mtool.cleanstamp.$opts{id}." . ($curstamp - $rdelay));
    # Remove previous stamps
    for my $stamp ( @stamps ) {
      $sh->rm( $stamp );
    }
    Mtool->info( "The time stamp check succeeded... Let's roll !" );
  } else {
    Mtool->info("The directory size check is temporarily disabled because the stamp check did not succeed")
      if ( $mksize );
    $mksize = 0;
  }
}

# --------------------------------------------------------------------------

# Compute the directory size
my $total = 0;
if ( $mksize ) {
  for my $item ( <$opts{path}> ) {
    $total += ( split /\s+/o, qx( du -sk $item ) )[0];
  }
}
my $fatdir = ( $mksize and $total > $opts{size} ) ? 1 : 0;
Mtool->info( "rootdir " . $opts{path} . " cummulated size is $total ko / too big ? $fatdir" )
  if ($opts{verbose} and $mksize);

# --------------------------------------------------------------------------

my @rmitems = ();

# With the crude option, a "usual" find is launched. It checks for files that
# have an access time older that $opts{old}.
if ( $opts{crude} ) {
  if ( $stampcheck ) {
    my $findcmd = $opts{lfs}
                  ? "lfs find $opts{path} --atime +$opts{old} -type f -print"
                  : "find $opts{path} -atime +$opts{old} -type f -print";
    Mtool->info("Running: $findcmd") if ( $opts{verbose} );
    @rmitems = map {
      chomp;
      [ $_, $opts{old} + 1, 0 ]
    } qx( $findcmd );
  } else {
    Mtool->info("This cleaning is temporarily disabled because the stamp check did not succeed");
  }
}

# This check (--nocrude) is intended for Olive/Vortex cache cleaning. It only 
# checks the first level of directories below the experiment ID (directories named 
# with the date/time). This is a lot less costfull than a "find".
# NB: It only works if Olive/Vortex do a "touch" on that directory name whenever
#     a new file is dropped in the cache.
if ( not $opts{crude} ) {

  my $rmcount = 1;
  for my $item ( <$opts{path}/*> ) {
  
    next unless ( -d "$item" and "$item" ne "$ENV{HOME}" );

    my $age = -M "$item";
    next unless ( defined $age );

    if ( $opts{recurse} and $age > $opts{old} ) {
      find( {
        wanted => sub {
          my $m = -M "$_";
          $age = $m if ( defined $m and $m < $age );
        },
        follow_skip => 0,
        no_chdir    => 1,
      }, $item );
    }

    my $size = $fatdir ? ( split /\s+/o, qx( du -sk $item ) )[0] : 0;

    Mtool->info( "look at $item old = $age / size = $size ko" )
      if $opts{verbose};

    if ( $age > $opts{old} or $fatdir ) {
      push @rmitems, [ $item, $age, $size ];
      last if ( ++$rmcount > $opts{max} and not $fatdir );
    }
  }
}

# --------------------------------------------------------------------------

# The real rm will take place here...
my $rmcount = 1;
my $rmstamp = time();
my $elapsed = 0;
for my $inode ( reverse sort { $a->[1] <=> $b->[1] } @rmitems ) {
  my ( $idir, $iold, $isize ) = @$inode;
  my $t = sprintf "#%4d / %7.3f", $rmcount, $iold;
  $total -= $isize;
  Mtool->info( "removing $idir $t days old / $total ko (elapsed time: $elapsed s)" );
  $sh->rm( $rmopts, $idir ) if $opts{remove}; 
  $elapsed = time() - $rmstamp;
  last if (
    # The maximum rm count is exceeded
    ++$rmcount > $opts{max} or
    # Fatdir did his job... it is pointless to continue
    (
      ( $fatdir and $total < $opts{size} ) and $iold < $opts{old}
    ) or
    # The allowed elapsed time is exceeded
    (
      $opts{rmmaxtime} > 0 and $elapsed >= $opts{rmmaxtime}
    )
  );
}

# --------------------------------------------------------------------------
$fakelock->free();

