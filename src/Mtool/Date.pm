package Mtool::Date;

use strict;


sub YYYY {
  my ( $class, $date ) = @_;
  return substr( $date, 0, 4 );
} 

sub MM {
  my ( $class, $date ) = @_;
  return substr( $date, 4, 2 );
} 

sub DD {
  my ( $class, $date ) = @_;
  return substr( $date, 6, 2 );
} 

sub HH {
  my ( $class, $date ) = @_;
  return sprintf "%02d", substr( $date, 8, 2 );
} 

sub RR {
  my ( $class, $date ) = @_;
  return substr( $date, 8, 2 );
} 

sub MN {
  my ( $class, $date ) = @_;
  return ( length( $date ) > 10 )
    ? sprintf "%02d", substr( $date, 10, 2 )
    : undef;
} 

sub date_items {
  return qw( YYYY MM DD HH MN );
}

sub AUTOLOAD {
  my $class = shift;
  ( my $format = our $AUTOLOAD ) =~ s/.*:://o;
  1 while ( $format =~ s/(YYYY|MM|DD|HH|RR|MN)/ $class->$1(@_) /ego );
  return $format;
}

sub floor {
  my ( $x ) = @_;
  my $i = int( $x );
  return ( $x > 0 ) || ( $x == $i ) ? $i : int( $x - 1 );
}

sub add_delta_date {
  my ( $class, $stamp, @delta ) = @_;

  my ( $year, $month, $day, $hour, $min ) = ( 0..4 );
  
  my @d0 = map { $class->$_( $stamp ) || 0 } $class->date_items();
  my @d1 = ();

  for ( $year, $month, $day, $hour, $min ) {
    $d1[$_] = $d0[$_] + ( $delta[$_] || 0 );
  }

  my $hhoff  = floor( $d1[$min] / 60 );
  $d1[$min]  = $d1[$min] - $hhoff * 60;
  $d1[$hour] = $d1[$hour] + $hhoff;

  my $ddoff  = floor( $d1[$hour] / 24 );
  $d1[$hour] = $d1[$hour] - $ddoff * 24;
  $d1[$day]  = $d1[$day] + $ddoff;
  $d1[$day]  = $d1[$day] - 1 if ( $d1[$day] <= 0 );

  my @dd = $class->mm_length_in_yyyy( $d1[$year] );

  while ( $d1[$day] < 0 ) { 
    $d1[$month] = $d1[$month] - 1;
    if ( $d1[$month] == 0 ) {
      $d1[$month] = 12;
      $d1[$year] = $d1[$year] - 1;
    }
    @dd = $class->mm_length_in_yyyy( $d1[$year] );
    $d1[$day] = $d1[$day] + $dd[ $d1[$month] ] + 1;
  }

  while ( $d1[$day] > $dd[ $d1[$month] ] ) {
    $d1[$day] = $d1[$day] - $dd[ $d1[$month] ];
    $d1[$month] = $d1[$month] + 1;
    if ( $d1[$month] == 13 ) {
      $d1[$year] = $d1[$year] + 1;
      $d1[$month] = 1;
    } 
    @dd = $class->mm_length_in_yyyy( $d1[$month] );
  }

  return substr( sprintf("%04d%02d%02d%02d%02d", @d1 ), 0, length( $stamp ) );
}

sub add_yyyymmddhh_hh {
  my ( $class, $yyyymmddhh, $hhoff ) = @_;

  my ( $yyyy0, $mm0, $dd0, $hh0 ) = ( $yyyymmddhh =~ /^(....)(..)(..)(..)$/o );


  my ( $hh1, $dd1, $mm1, $yyyy1 ) = ( $hh0 + $hhoff, $dd0, $mm0, $yyyy0 );

  my $ddoff = floor( $hh1 / 24 );
  $hh1 = $hh1 - $ddoff * 24;
  $dd1 = $dd1 + $ddoff;
  $dd1 = $dd1 - 1 if ( $dd1 <= 0 );

  my @dd = $class->mm_length_in_yyyy( $yyyy1 );

  while ( $dd1 < 0 ) { 
    $mm1 = $mm1 - 1;
    if ( $mm1 == 0 ) {
      $mm1 = 12;
      $yyyy1 = $yyyy1 - 1;
    }
    @dd = $class->mm_length_in_yyyy( $yyyy1 );
    $dd1 = $dd1 + $dd[ $mm1 ] + 1;
  }

  while ( $dd1 > $dd[ $mm1 ] ) {
    $dd1 = $dd1 - $dd[ $mm1 ];
    $mm1 = $mm1 + 1;
    if ( $mm1 == 13 ) {
      $yyyy1 = $yyyy1 + 1;
      $mm1 = 1;
    } 
    @dd = $class->mm_length_in_yyyy( $yyyy1 );
  }

  return sprintf("%4.4d%2.2d%2.2d%2.2d", $yyyy1, $mm1, $dd1, $hh1 );
}

sub yyyy_is_bissextil {
  my ( $class, $yyyy ) = @_;
  return ( ( $yyyy % 4 ) == 0 ) &&
    ( ( ( $yyyy % 100 ) != 0 ) || ( ( $yyyy % 400 ) == 0 ) );
}

sub mm_length_in_yyyy {
  my ( $class, $yyyy ) = @_;
  return $class->yyyy_is_bissextil( $yyyy )
    ? qw( 0 31 29 31 30 31 30 31 31 30 31 30 31 )
    : qw( 0 31 28 31 30 31 30 31 31 30 31 30 31 );
}

sub today {
  my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = gmtime( time() ); 
  return sprintf "%d%02d%02d", $year+1900, $mon+1, $mday;
}


1;
