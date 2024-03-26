#!/usr/bin/perl -w 

use strict;

use FindBin qw ($Bin);
use lib "$Bin/../src";

use Mtool;
use Mtool::Shell;
use Getopt::Long;
use File::Find;
use Net::FTP;

my %opts = (
  path   => '*',
  root   => undef,
  host   => 'hendrix',
  user   => undef,
  max    => 25,
  stop   => 10000,
  trace  => 1,
  select => '.',
  sleep  => 0,
  off    => 0,
);

GetOptions(
  \%opts,
  qw( root=s path=s sleep=s select=s host=s max=i stop=i trace! off! )
) or die "usage: mtool_mirror.pl\n  [--path=path-name]\n  [--root=remote-root-path]\n  [--host=host-name]\n  [--select=file-regexp]\n  [--stop=max-proceed-number]\n  [--max=max-block-size]\n  [--[no]trace]\n";

my $sh = new Mtool::Shell;
$sh->set( '-x' ) if delete $opts{trace};

my @upds = ();
my %dirs = ();
my %done = ();

my $select = join '|', split /,/, $opts{select};

for my $item ( <$opts{path}> ) {
  
  next unless ( -d "$item" and "$item" ne "$ENV{HOME}" );

  print "  processing $item ...\n";
  find( {
    wanted => sub {
      push @upds, $File::Find::name if ( $File::Find::name =~ /(?:$select)/o );
    },
    follow_skip => 0,
    no_chdir    => 1,
  }, $item );

}

for ( @upds ) {
  ( my $d = $_ ) =~ s/\/[^\/]+$//go;
  $dirs{$d}++;
}

my $user = delete $opts{user} || getpwuid( $< );
my $ftp = new Net::FTP( $opts{host}, Timeout => 900 )
  or die "could not open a ftp session\n";
$ftp->login( $user )
  or die "Could not login at $opts{host} user $user\n";
$ftp->binary();

for ( sort keys %dirs ) {
  my $target = $opts{root} ? "$opts{root}/$_" : $_;
  my @d = split /\//, $target;
  my $rd = '';
  for my $sd ( @d ) {
    $rd .= '/' if ( $rd =~ /\S/o );
    $rd .= $sd;
    unless ( $done{$rd}++ ) {
      print "  mkdir $rd ...\n";
      $ftp->mkdir( $rd ) unless ( $opts{off} );
    }
  }
}

for ( grep { -f $_ } @upds ) {
  my $rf = $opts{root} ? "$opts{root}/$_" : $_;
  print "  upd $_ to $rf ...\n";
  unless ( $opts{off} ) {
    $ftp->put( $_, $rf );
    sleep( $opts{sleep} );
  }
}

$ftp->close();

