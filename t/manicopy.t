use strict;
use warnings;

use lib 't/lib';
use ManifestTest qw( catch_warning canon_warning spew slurp runtemp );
use ExtUtils::Manifest qw( manicopy );
use Test::More tests => 16;
use Config;

runtemp "manicopy.emptylist" => sub {
  note "Sanity check running manicopy with no work to do";
  ok( ( mkdir 'target', 0700 ), 'make target dir ok' );
  my ( $exit, $warn ) = catch_warning sub { manicopy( {}, 'target' ) };
  is( $warn, '', 'No-op = no warning' );
};

runtemp "manicopy.basic" => sub {
  note "Copying a file";
  ok( ( mkdir 'target', 0700 ), 'make target dir ok' );
  spew( 'file', "####" );
  my $source = 'file';
  my $target = 'target/file';

  my ( $exit, $warn ) = catch_warning sub { manicopy( { 'file' => 'description' }, 'target', 'cp' ) };
  is( $warn, '', 'no warning' );
  ok( -e $target, 'Copied ok' );
  is( slurp($target), '####', 'Content preserved' );
  ok( -r $target, 'Copied file should be readable' );
  is( -x $target, -x $source, '-x bits copied' );
  is( -w $target, -w $source, '-w bits copied' );
};

runtemp "manicopy.executable" => sub {
  note "Copying a file that might have -x bits";

SKIP: {
    # This ensures the -x check for manicopy means something
    # Some platforms don't have chmod or an executable bit, in which case
    # this call will do nothing or fail, but on the platforms where chmod()
    # works, we test the executable bit is copied

    skip "No Exec bits support for copy test", 5 unless $Config{'chmod'};

    ok( ( mkdir 'target', 0700 ), 'make target dir ok' );
    spew( 'execfile', "####" );
    chmod( 0744, 'execfile' );
    ok( -x 'execfile', 'Created an -x file' );
    my ( $exit, $warn ) = catch_warning sub { manicopy( { 'execfile' => 'description' }, 'target' ) };
    is( $warn, '', 'no warning' );
    ok( -e 'target/execfile', 'Copied ok' );
    ok( -x 'target/execfile', '-x bits copied' );
  }
};

runtemp 'manicopy.warn_missing' => sub {
  note "Copying a file that doesn't exist";
  ok( ( mkdir 'target', 0700 ), 'make target dir ok' );
  my ( $exit, $warn ) = catch_warning sub { manicopy( { none => 'none' }, 'target', 'cp' ) };
  like( $warn, qr/^none not found/, 'carped about missing file' );
};
