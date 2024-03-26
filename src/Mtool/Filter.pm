package Mtool::Filter;

use strict;

use Mtool;
use base qw( Mtool::Kit );

use Mtool::Util::Nice;
use Mtool::Util::Counter;
use Mtool::Script;

use POSIX qw();
use Sys::Hostname qw();
use Data::Dumper;

our %LANGXT = (
  perl => 'pl',
  python => 'py',
  ksh => 'sh',
);

sub new {
  my $class = shift;

  ( my $hostname = &Sys::Hostname::hostname() ) =~ s/\d[-\d]*\..*$//;
  $hostname = 'prefix' if ( $hostname eq 'login' );
  $hostname =~ s/(?:login|transfert|ppn)$//;

  my $self = {
    host          => $hostname,
    suffixfe      => 'fe',
    suffixcn      => 'cn',
    user          => $ENV{SWAPP_USER} || $ENV{LOGNAME} || $ENV{USER},
    verbose       => $ENV{MTOOL_VERBOSE} || 0,
    root          => $ENV{MTOOL_ROOT} || "$ENV{HOME}/bench/mtool",
    public        => $ENV{MTOOL_PUBLIC} || '__ROOT__/public',
    mtoolrc       => $ENV{MTOOL_RC} || "$ENV{HOME}/.mtoolrc",
    ftdir         => $ENV{FTDIR} || "$ENV{HOME}/tmp",
    mtooldir      => $ENV{MTOOLDIR} || '__FTDIR__/mtool',
    tmploc        => '$TMP_LOC',
    tmpdir        => '$TMPDIR',
    workdir       => $ENV{WORKDIR},
    depotroot     => $ENV{MTOOL_DEPOTROOT} || '__MTOOLDIR__/depot',
    spoolroot     => $ENV{MTOOL_SPOOLROOT} || '__MTOOLDIR__/spool',
    cacheroot     => $ENV{MTOOL_CACHEROOT} || '__MTOOLDIR__/cache',
    abortroot     => $ENV{MTOOL_ABORTROOT} || '__MTOOLDIR__/abort',
    aliveroot     => $ENV{MTOOL_ALIVEROOT} || '__MTOOLDIR__/alive',
    spool         => undef,
    incpath       => $ENV{MTOOL_INCPATH} || '.',
    node          => $ENV{MTOOL_NODE} || $hostname,
    shell         => $ENV{MTOOL_SHELL} || 'ksh',
    language      => $ENV{MTOOL_LANGUAGE} || 'ksh',
    bangline      => undef,
    languagext    => undef,
    subshell      => 0,
    export        => 'no',
    submit        => 0,
    jobtag        => undef,
    jobname       => 'mtool',
    jobtest       => undef,
    notdefault    => 'autolog',
    logfile       => undef,
    logtarget     => undef,
    autolog       => 'off',
    autoclean     => 'off',
    cleanmode     => undef,
    submitcmd0    => undef,
    submitcmd     => $ENV{MTOOL_SUBMITCMD} || 'sbatch',
    submitmethod  => $ENV{MTOOL_SUBMITMETHOD} ||'slurm',
    header        => [],
    epilog        => [ '#MTOOL include files=epilog.step,banner.end' ],
    steps         => [],
    on_error      => [],
    inclprompt    => 'on',
    proftag       => 'default',
    profiles      => {},
    profiles_ext  => {},
    variables     => {},
    setvars       => undef,
    evalcode      => [],
    nest          => undef,
    id            => undef,
    stdin         => 0,
    job           => undef,
    time          => 0,
    timer         => 'time',
    jshort        => undef,
    lockstyle     => 'flock',
    $class->opt2hash( @_ ),
    # Langage specific stuff...
    pycoding      => undef,
    pyfuture      => undef,
  };

  for ( 1..2 ) {
    $self->{$_} =~ s/__([A-Z]+)__/$self->{lc($1)}/ego
      for ( grep { defined $self->{$_} and not ref( $self->{$_} ) } keys %$self );
  }

  bless $self, $class;

  $ENV{MTOOL_RC} = $self->{mtoolrc};

  $self->fatal( "no job file defined or no stdin input" )
    unless ( defined $self->{job}  or $self->{stdin} );

  $self->shell->set( '-x' ) if ( $self->{verbose} );

  if ( defined $self->{setvars} ) {
    for my $setpack ( split /,/o, delete $self->{setvars} ) {
      my ( $setvar, $setvalue ) = split /:/o, $setpack;
      $self->info( "external set $setvar = $setvalue" ) if $self->{verbose};
      $self->{variables}{$setvar} = $setvalue;
    }
  }

  unless ( defined $self->{logfile} ) {
    $self->{logfile} = $ENV{MTOOL_LOGROOT} || $ENV{PWD};
    if ($self->{stdin} ) {
      $self->{jshort} = 'stdin';
    } else {
      ( $self->{jshort} = $self->{job} ) =~ s/^.*\///go;
    }
    $self->{logfile} .= "/$self->{jshort}.o$$";
  } 

  $self->{languagext} = $LANGXT{$self->{language}} unless ( defined $self->{languagext} );
  $self->{subshell} = 1 if ( $self->{language} ne $self->{shell} );
  $self->{bangline} = "/bin/$self->{shell}" unless ( defined $self->{bangline} );

  $self->{frontend} = $self->{host} . $self->{suffixfe} unless ( defined $self->{frontend} );
  $self->{cpunodes} = $self->{host} . $self->{suffixcn} unless ( defined $self->{cpunodes} );

  $self->{logtarget} = $self->{frontend} unless ( defined $self->{logtarget} );

  $self->{nested} = defined $self->{nest} ? 'on' : 'off';

  $self->{variables}{$_} = delete $self->{$_}
    for ( qw(
      notdefault logfile logtarget host frontend cpunodes suffixfe suffixcn
      spoolroot spool depotroot cacheroot abortroot aliveroot
      ftdir tmpdir tmploc workdir public
      jobname jobtag proftag cleanmode nested bangline
    ) );

  $self->shell->mkdir( '-p', "$self->{variables}{abortroot}" )
    unless ( -d "$self->{variables}{abortroot}" );

  $self->shell->mkdir( '-p', "$self->{variables}{aliveroot}" )
    unless ( -d "$self->{variables}{aliveroot}" );

  $self->shell->mkdir( '-p', "$self->{variables}{cacheroot}/logs" )
    unless ( -d "$self->{variables}{cacheroot}/logs" );

  $self->{search} = [
    split( /:/o, $self->{incpath} ),
    "$self->{mtoolrc}/include/__LANG__", "$self->{mtoolrc}/include", $self->{mtoolrc},
    "$self->{root}/include/__LANG__", "$self->{root}/include", $self->{root}
  ];

  $self->{steps} = [ $self->newstep( -join => 'all', -active => 'no', -not => '_xxx_' ) ];

  $self->{inclprompt} = ( $self->{inclprompt} =~ /^(?:0|off|ko|no)$/io ) ? 0 : 1;

  return $self;
}

sub mkcount {
  my ( $self, @args ) = @_;

  my %args = (
    item => 'void',
    $self->opt2hash( @args )
  );

  return sprintf '%06d', Mtool::Util::Counter->plus( -item => $args{item}, -lockstyle => $self->{lockstyle} );
}

sub mktempo {
  my ( $self, @args ) = @_;

  my %args = (
    mk     => 0,
    num    => 0,
    config => 0,
    prefix => 'tmp',
    $self->opt2hash( @args )
  );

  $self->shell->mkdir( '-p', $args{rootdir} ) unless ( -d "$args{rootdir}" );

  my $id = sprintf '%s_%06d', $args{prefix}, $args{num};

  if ( defined $self->{variables}{jobtag} ) {
    my @tags = reverse grep /\S/o, map { s/_//go; $_ } split/\W+/, $self->{variables}{jobtag};
    $id = join '_', $id, @tags;
  }

  if ( $args{mk} ) {
    $self->shell->mkdir( "$args{rootdir}/$id" );
    if ( $args{config} ) {
      open CONFIG, ">$args{rootdir}/$id/MTOOLRECORD";
      print CONFIG Mtool::Util::Nice->dump( $self );
      close CONFIG;
    }
  }

  return $id;
}

sub newstep {
  my ( $self, @args ) = @_;

  my %args = $self->opt2hash( @args );

  my $newst = {
    shell         => $self->{shell},
    subshell      => $self->{subshell},
    initsh        => undef,
    language      => $self->{language},
    submitcmd0    => $self->{submitcmd0},
    submitcmd     => $self->{submitcmd},
    submitmethod  => $self->{submitmethod},
    join          => '_xxx_',
    not           => $self->{variables}{notdefault},
    active        => 'yes',
    type          => 'std',
    id            => 'void',
    order         => 0,
    number        => undef,
    target        => $self->{variables}{host},
    public        => $self->{variables}{public},
    proftag       => $self->{variables}{proftag},
    corpus        => [],
    %args,
  };

  $newst->{languagext} = $LANGXT{$newst->{language}} unless defined $newst->{languagext};

  $newst->{initsh} = $newst->{language} unless defined $newst->{initsh};

  return $newst;
}

sub script {
  my ( $self, @args ) = @_;

  my %args = $self->opt2hash( @args );

  my $language = delete $args{language};
  my $do = delete $args{do};

  unless ( defined $self->{script}{$language} ) {
    $self->{script}{$language} = new Mtool::Script( -language => $language, -filter => $self );
    $self->{script}{$language}->setup( -time => $self->{time}, -timer => $self->{timer} );
  }

  $self->{script}{$language}->$do( %args );
}

sub process {
  my ( $self, @args ) = @_;

  my %addargs = $self->opt2hash( @args );
  while ( my ($k, $v) = each ( %addargs ) ) {
    $self->{$k} = $v;
  }

  my @code;
  if ($self->{stdin})  {
      @code = <STDIN>;
      $self->info( "processing stdin" );
  } else {
      open JOB, "<$self->{job}"
          or $self->fatal( "could not open job file $self->{job}" );
      @code = <JOB>;
      close JOB;
      $self->info( "processing job < $self->{job} >" );
  }

  my $switch = 'on';
  my $defid  = 0;
  my @record = ();
  my %recording = ();
  my $step = 0;
  my $target = undef;
  my $target_ext = undef;
  my $setting = 0;

  while ( @code ) {

    my $line = shift @code;
    my $leadblks = ( $line =~ /^(\s+)/o ) ? "$1" : '';
    $line =~ s/^(\s+)//o;
    my @more = ( $line );

    $setting = 1 if ( $line =~ /^# setconf start/o );
    push @{ $recording{$record[0]} }, $line if ( @record and not $setting );
    $setting = 0 if ( $line =~ /^# setconf end/o );

    if ( $line =~ /^\s*\#\s*mtool\s+(\w+.*)\s*$/io ) {

      ( my $cmdline = $1 ) =~ s{
        \[\[\s*(\S.*)\s*\]\](?!\])
      }{
        push @{ $self->{evalcode} }, $1;
        $self->info( "code << $1 >>" ) if $self->{verbose};
        '__internal_' . scalar( @{ $self->{evalcode} } ) . '__'
      }eigxo;

      #$self->info( "cmdline $cmdline" ) if $self->{verbose};

      my ( $action, %args ) = split /[\s=]+/o, $cmdline;

      for ( $action ) {
	
        /^(?:on|off)$/io and do {
          $switch = lc( $action );
          next;
        };

        next unless ( $switch eq 'on' );

        /^record$/io and do {
          if ( @record ) {
            pop @{ $recording{$record[0]} } if ( @record );
            push  @{ $recording{$record[0]} }, "#MTOOL $args{as} files=[this:jobname].$args{tag}"
              if ( defined $args{as} );
          }
          unshift @record, $args{tag};
          $recording{$args{tag}} ||= [];
          pop @more;
          next;
        };

        /^turnoff$/io and do {
          pop @{ $recording{$record[0]} } if ( @record );
          shift @record;
          pop @more;
          next;
        };

        /^profile$/io and do {
          $target = join '_', $self->resolve( -string => delete $args{target} ) || 'auto', delete $args{tag} || 'default';
          $self->{profiles}{$target} = [];
          pop @more;
          next;
        };

        $target = undef;

        /^extendprofile$/io and do {
          $target_ext = join '_', $self->resolve( -string => delete $args{target} ) || 'auto', delete $args{tag} || 'default';
          pop @more;
          next;
        };

        $target_ext = undef;

        /^configure$/io and do {
          $self->{steps}[$step]{$_} = $args{$_} for ( keys %args );
          next;
        };

        /^set$/io and do {
          for ( keys %args ) {
            $self->{variables}{$_} = $self->resolve( -string => $args{$_} ) for ( keys %args );
            print $self->info( "set variable $_ as $self->{variables}{$_}" ) if ( $self->{verbose} > 1 );
          }
          next;
        };

        /^setconf$/io and do {
          my @includes = $self->include_file(
            -file => [ map { s/\"//go; $_ } split /,/o, $self->resolve( -string => $args{files} ) ],
            -lang => $self->{steps}[$step]{language},
          );
          for my $inc ( @includes ) {
            open INCLUDE, "<$inc"
              or $self->fatal( "could not include $inc" );
            unshift @code, (
              "# setconf start $inc\n",
              <INCLUDE>,
              "# setconf end\n\n"
            );
            close INCLUDE;
            $self->info( "setconf $inc" ) if $self->{verbose};
          }
          next;
        };

        /^autolog$/io and do {
          $self->{$_} = 'on';
          push @code,
            "#MTOOL step id=autolog target=[this:logtarget] tag=autolog language=$self->{shell} subshell=0\n",
            "#MTOOL include files=auto.log.[this:logtarget]\n";
          next;
        };

        /^autoclean$/io and do {
          $self->{$_} = 'on';
          next;
        };

        /^(step|common)$/io and do {
          my $bloc = lc( $1 );
          $step++;
          $args{join} = delete $args{shared} if ( exists $args{shared} );
          $args{proftag} = delete $args{tag} if ( exists $args{tag} );
          $self->info( "common join $args{join}" )
            if ( $self->{verbose} and $bloc eq 'common' and defined $args{join} );
          $self->{steps}[$step] = ( $bloc eq 'common' )
            ? $self->newstep( -join => 'all', %args, -order => $step, -active => 'no' )
            : $self->newstep( %args, -order => $step );
          $self->{steps}[$step]{target} = $self->{steps}[0]{target}
            if ( $self->{steps}[$step]{target} && ($self->{steps}[$step]{target} eq 'auto') );
          $self->{steps}[$step]{target} = $self->{steps}[$step-1]{target}
            if ( $self->{steps}[$step]{target} && ($self->{steps}[$step]{target} eq 'prev') );
          next;
        };

      }
    }

    if ( $target ) {
      push @{ $self->{profiles}{$target} }, map { "$leadblks$_" } @more;
      next;
    }

    if ( $target_ext ) {
      push @{ $self->{profiles_ext}{$target_ext} }, map { "$leadblks$_" } @more;
      next;
    }

    push @{ $self->{steps}[$step]{corpus} }, map { "$leadblks$_" } @more;
  }

  if ( defined $self->{variables}{jobtest} and -d "$self->{variables}{jobtest}" ) {
    my $recroot = "$self->{variables}{jobtest}/$self->{variables}{jobname}";
    for my $rectag ( keys %recording ) {
      open RECORD, ">$recroot.$rectag";
      print RECORD @{$recording{$rectag}};
      close RECORD;
    }
    chdir "$self->{variables}{jobtest}";
  }

  $self->{variables}{count} = $self->mkcount( -item => 'mstep' );

  $self->{id} ||= $self->mktempo(
    -mk      => 1,
    -num     => $self->{variables}{count},
    -prefix  => 'mstep',
    -rootdir => $self->{variables}{depotroot},
  );

  $self->{variables}{abort} ||= $self->mktempo(
    -mk      => 0,
    -num     => $self->{variables}{count},
    -prefix  => 'dump',
    -rootdir => $self->{variables}{abortroot},
  );

  $self->{variables}{spool} ||= $self->mktempo(
    -mk      => 1,
    -num     => $self->{variables}{count},
    -config  => 1,
    -prefix  => 'spool',
    -rootdir => $self->{variables}{spoolroot}
  );

  $self->{depot} = "$self->{variables}{depotroot}/$self->{id}";
  push @{ $self->{on_error} }, $self->{depot}, $self->{variables}{spool};

  my $last = 0;
  my $first = undef;
  my $submitted = 0;
  my $ix = "01";
  # Deal with spaces in the bangline
  ( my $bangline = "#!$self->{variables}{bangline}\n" ) =~ s/_+-/ -/go;
  $bangline =~ s/env_/env /go;
  for ( reverse @{ $self->{steps}[0]{corpus} } ) {
    /^\#\!/o and do {
      $bangline = $_;
      s/^\#\!(.*)$/#MTOOL removing bangline $1/o;
    };
  }
  ( my $pycoding = (defined $self->{variables}{pycoding}) ?
                   "# -*- coding: $self->{variables}{pycoding} -*-\n" :
                   '' ) =~ s/_+/ /go ;
  my $pyfuture = (defined $self->{variables}{pyfuture}) ?
                 "from __future__ import $self->{variables}{pyfuture}\n" :
                 '';

  for ( my $s = 1; $s <= $step; $s++ ) {

    my $st = $self->{steps}[$s];
    $st->{$_} = $self->resolve(
      -string => $st->{$_},
      -step => $s, -max => $step
    ) for ( grep { defined $st->{$_} and not ref( $st->{$_} ) } keys %{ $st } );

    next if (  $st->{active} eq 'no' );

    $st->{number} = $ix++;
    $st->{output} = "$self->{depot}/step.$st->{number}.out";

    $first = $s unless $first;
    $last = $s;

  }

  for ( my $s = 1; $s <= $last; $s++ ) {
  
    my $st = $self->{steps}[$s];

    next if ( $st->{active} eq 'no' );

    my ( $stnext ) = grep { $_->{active} } map { $self->{steps}[$_] } ( $s+1 .. $last );

    $ix = $st->{number};
    my $starget = $st->{target};
    my $ptarget = join '_', $starget, $st->{proftag};
    my $id = $st->{id};
    my @src = ( $bangline, $pycoding );

    $self->info( "processing step $ix ( id = $id / target = $starget )" );

    if ( exists $self->{profiles}{$ptarget} ) {
      push @src, @{ $self->{profiles}{$ptarget} };
    } else {
      push @src, "#MTOOL include files=profile/$st->{submitmethod}.$st->{proftag}.$starget\n";
    }
    if ( exists $self->{profiles_ext}{$ptarget} ) {
      push @src, @{ $self->{profiles_ext}{$ptarget} }, "\n";
    } else {
      push @src, "\n";
    }

    push @src,
      $pyfuture,
      "#MTOOL include files=setup.load\n",
      "#MTOOL include files=banner.start\n",
      "#MTOOL export MTOOL_VERSION=$Mtool::VERSION\n",
      "#MTOOL export MTOOL_STEP=$ix\n",
      "#MTOOL export MTOOL_STEP_ID=[this:id]\n",
      "#MTOOL export MTOOL_STEP_IDNUM=[this:id].[this:count]\n",
      "#MTOOL export MTOOL_STEP_TARGET=[this:target]\n",
      "#MTOOL export MTOOL_STEP_PUBLIC=[this:public]\n",
      "#MTOOL export MTOOL_STEP_DEPOT=[this:depot]\n",
      "#MTOOL export MTOOL_STEP_CACHE=[this:cacheroot]\n",
      "#MTOOL export MTOOL_STEP_ABORT=[this:abortroot]/[this:abort]\n",
      "#MTOOL export MTOOL_STEP_SPOOL=[this:spoolroot]/[this:spool]\n";

    push @src, "#MTOOL export MTOOL_STEP_LOGFILE=[this:logfile]\n"
      if ( $self->{autolog} eq 'on' and $self->{variables}{logfile} );

    push @src,
      @{ $self->{header} },
      @{ $self->{steps}[0]{corpus} },
      "#MTOOL include files=setup.broadcast.env\n\n";

    push @src,
      "#MTOOL include files=path.$st->{initsh}.$starget\n",
      "#MTOOL subshell switch=on\n"
        if $st->{subshell};

    for ( my $p = 1; $p <= $step; $p++ ) {
      if (
        $p == $s or
        (
          ( $self->{steps}[$p]{join} eq 'all' or $self->{steps}[$p]{join} =~ /\b$id/i ) and
          $self->{steps}[$p]{language} eq $st->{language} and
          $self->{steps}[$p]{not} !~ /\b$id/i
        )
      ) {
        push @src, @{ $self->{steps}[$p]{corpus} };
      }
    }

    push @src, "#MTOOL subshell switch=off\n" if $st->{subshell};

    push @src, map { chomp; "$_\n" } @{ $self->{epilog} };

    if ( $s == $last ) {
      push @src,
        "#MTOOL include files=epilog.clean.broadcast\n",
        "#MTOOL include files=epilog.clean.spool\n";
      if ( $self->{autoclean} eq 'on' ) {
        my $cleanmode= defined $self->{variables}{cleanmode}
          ? "autoclean.$self->{variables}{cleanmode}"
          : 'auto.clean';
        push @src, "#MTOOL include files=$cleanmode.[this:target]\n\n";
      }
    } else {
      my $tool = "";
      if ( defined $stnext and defined $self->{nest} ) {
        my ( $n_xpid, $n_name, $n_mega, $n_step ) = split /:/o, $self->{nest};
        if ( $n_step =~ /\b$stnext->{id}\b/ ) {
          ( $stnext->{nestjob} = $self->{jshort} ) =~ s/(\.job\d+)$/.$stnext->{id}$1/;
          $tool = "tool=nest nestopts=$n_xpid,$n_name,$n_mega job=$stnext->{nestjob}";
        }
      }
      push @src, "#MTOOL submit step=[next:number] out=[this:depot]/step.[next:number].out $tool\n";
    }

    open STEP, ">$self->{depot}/step.$ix"
      or $self->fatal( "could not open file $self->{depot}/step.$ix" );

    open SUBSTEP, ">$self->{depot}/step.$ix.$st->{languagext}"
      or $self->fatal( "could not open file $self->{depot}/step.$ix.$st->{languagext}" );

    my $sublang = $st->{subshell} ? $self->{shell} : $st->{language};
    my $subswitch = 0;
    my $subcall = 0;
    my $tab = '';
    my $nbtab = 0;

    while ( @src ) {
      
      my $l = shift @src;
      my $line =  $self->resolve( -string => $l, -step => $s, -max => $step );
      my @more = ( $line );

      if ( $line =~ /^\s*\#\s*mtool\s+(\w+.*)\s*$/io ) {

      	my $command = $1;
      	next if ( $command eq 'end' );

        my $leadblks = ( $line =~ /^(\s+)/o ) ? "$1" : '';

        my ( $action, %args ) = split /[\s=]+/o, $command;

      	for ( $action ) {
	
      	  /^tab$/io and do {
            if ( $args{set} =~ /(?:add|more)/io ) {
              $nbtab += 1;
            } elsif ( $args{set} =~ /(?:back|less)/io ) {
              $nbtab -= 1;
            } elsif ( $args{set} =~ /(?:null|rewind)/io ) {
              $nbtab = 0;
            }
            $tab = '    ' x $nbtab;
            next;
          };

      	  /^subshell$/io and do {
            my $onoff = ( $args{switch} =~ /^(?:0|off|ko|no)$/io ) ? 0 : 1;
            $subswitch = $onoff;
            $subcall = $onoff;
            $sublang = $subswitch ? $st->{language} : $self->{shell};
            push @more, "$leadblks$st->{language} $self->{depot}/step.$ix.$st->{languagext}\n"
              if $subcall;
            next;
          };

      	  /^include$/io and do {
            my @includes = $self->include_file(
              -file => [ map { s/\"//go; $_ } split /,/o, $args{files} ],
              -lang => $subswitch ? $sublang : $self->{shell}
            );
            my $indent = defined $args{indent} ? ' ' * $args{indent} : '';
            for my $inc ( @includes ) {
              open INCLUDE, "<$inc"
                or $self->fatal( "could not include $inc" );
              my @thisinclude = <INCLUDE>;
              close INCLUDE;
              if ( $self->{inclprompt} ) {
                @thisinclude = ( 
                  "# include top $inc\n",
                  @thisinclude,
                  "# include end\n\n"
                );
              }
              unshift @src, map { "$leadblks$indent$_" } @thisinclude;
              $self->info( "include $inc" ) if $self->{verbose};
            }
            next;
          };

      	  /^export$/io and do {
            push @more, $self->script(
              -language => $sublang,
              -do => 'export',
              -indent => $leadblks,
              %args
            );
            next;
          };

      	  /^broadcast$/io and do {
            for my $type ( sort split /,/o, ( delete( $args{type} ) || 'env' ) ) {
              my $brfile =  $self->resolve(
                -string => "[this:depot]/mtool.bcast.$type.$args{id}",
                -step => $s, -max => $step
              );
              push @more, $self->script(
                -language => $sublang,
                -do       => 'broadcast',
                -file     => $brfile,
                -indent   => $leadblks,
                %args
              ) if ( $args{vars} );
              unshift @src, join( ' ',
                "$leadblks#MTOOL track bcast=$brfile tag=$args{track} type=$type",
                map(
                  { "$_=$args{$_}" } grep { defined $args{$_} }
                  qw( trace delay verbose deep packing packmin packbig discard filter )
                ),
                "\n" ) if ( $args{track} );
            }
            next;
          };

      	  /^(banner|clean|track|import|fsync|wait)$/io and do {
            push @more, $self->script(
              -language => $sublang,
              -do => 'function',
              -cmd => $1,
              -indent => $leadblks,
              %args
            );
            next;
          };

      	  /^submit$/io and do {
            my %realargs = (
              depot => $self->{depot},
              tool  => $st->{submitcmd},
              %args
            );
            $realargs{tag} = "submit.$realargs{tag}" if defined $realargs{tag};
            push @more, $self->script(
              -language => $sublang,
              -do => 'function',
              -cmd => 'submit',
              -indent => $leadblks,
              %realargs
            );
            next;
          };

        }
      }

      if ( $subswitch and not $subcall ) {
        print SUBSTEP map { "$tab$_" } @more;
      } else {
        print STEP map { "$tab$_" } @more;
        $subcall = 0;
      }

    }

    close STEP;
    close SUBSTEP;
    unlink "$self->{depot}/step.$ix.$st->{languagext}" unless $st->{subshell};

    $self->shell->ln( '-s', "$self->{depot}/step.$ix", "$self->{depot}/$st->{nestjob}" )
      if ( defined $st->{nestjob} );
  }

  if ( $self->{submit} and $first ) {
    my $stfirst = $self->{steps}[$first];
    my $stsubmitcmd = defined $stfirst->{submitcmd0} ? $stfirst->{submitcmd0} : $stfirst->{submitcmd};
    $self->shell->spawn(
      "$self->{root}/bin/mtool_submit.pl",
      "--tool=$stsubmitcmd",
      "--step=$stfirst->{number}",
      "--out=$stfirst->{output}",
      "--public=$stfirst->{public}",
      "--depot=$self->{depot}"
    );
  }

  $self->info(
    "current depot is $self->{depot}",
    $self->{stdin} ? "job processed from stdin" : "job < $self->{job} > processed"
  );
}

sub resolve {
  my ( $self, %args ) = @_;

  my $string = $args{-string};
  my $step   = $args{-step} || 0;
  my $max    = $args{-max} || 0;

  $string =~ s{
    \[\s*(this|prev|next|first|last)\s*:\s*(\w+)\s*\]
  }{
    my $fix = $1;
    my $steval =  $self->{steps}[$step];
    my ( $init, $upd ) = ( $step, 0 );
    for ( $fix ) {
      /^prev$/io and do { $init--; $upd = -1; };
      /^next$/io and do { $init++; $upd = 1; };
      /^first$/io and do { $init = 1; $upd = 1; };
      /^last$/io and do { $init = $max; $upd = -1; };
    }
    if ( $upd ) {
      while ( $init >= 0 and $init <= $max ) {
      	if ( $self->{steps}[$init]->{active} ne 'no' ) {
	  $steval = $self->{steps}[$init];
	  last;
	}
	$init += $upd;
      }
    }
    my ( $node ) = grep { defined $_ and exists $_->{$2} } ( $steval, $self->{variables}, $self );
    $self->fatal( "no variable [$2] available in current context" )
      unless ( defined $node );
    $node->{$2};
  }eigxo;

  $string =~ s{
    \b(perl|python)__internal_(\d+)__
  }{
    my $lang = new Mtool::Script( -language => $1 );
    $self->info( "resolve internal $1($2)" ) if ( $self->{verbose} and $lang );
    defined $lang
      ? $lang->evaluate( $self->resolve( -string => $self->{evalcode}[$2-1], -step => $step, -max => $max ) )
      : 'undef';
  }eigxo;

  return $string;
}

sub include_file {
  my ( $self, %args ) = @_;

  my @files = ref( $args{-file} ) ? @{ $args{-file} } : ( $args{-file} );
  my $language = defined $args{-lang} ? $args{-lang} : $self->{shell};

  my @incldirs = grep { -d $_ } map { ( my $dir = $_ ) =~ s/__LANG__/$language/; $dir } @{ $self->{search} };
  my @includes = ();

  for my $file ( @files ) {
    my ( $found ) = grep { -f "$_/$file" } @incldirs;
    $self->fatal( "include file \"$file\" not found in search path ( @incldirs )" )
      unless $found;
    push @includes, "$found/$file";
  }

  return @includes;
}

1;
