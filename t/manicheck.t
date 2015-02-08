use strict;
use warnings;

use lib 't/lib';
use ManifestTest qw( catch_warning canon_warning spew runtemp );
use ExtUtils::Manifest qw( manicheck );
use Test::More tests => 6;

runtemp "manicheck.blank_manifest" => sub {
  note "Blank Manifest File";
  spew( "MANIFEST", "" );
  my (@missing) = manicheck();
  ok( !@missing, 'manicheck vs blank MANIFEST file in otherwise empty dir == OK! No missing files' );
};

runtemp "manicheck.self_manifest" => sub {
  note "Self-Containing Manifest File";
  spew( "MANIFEST", "MANIFEST" );
  my (@missing) = manicheck();
  ok( !@missing, 'manicheck vs self-containing MANIFEST ok' );
};

runtemp "manicheck.missing_file" => sub {
  note "Manifest file with more files than on disk";
  spew( "MANIFEST", "MANIFEST\nNo_Such_File" );
  my (@missing);
  my ( $out, $err ) = catch_warning( sub { @missing = manicheck() } );
  cmp_ok( scalar @missing, '==', 1, 'manicheck with missing file returns list' );
  cmp_ok( $missing[0], 'eq', 'No_Such_File', 'No_Such_File reported missing' );
};

# There was a bug where entries in MANIFEST would be blotted out
# by MANIFEST.SKIP rules.
runtemp "manicheck.skipped_file" => sub {
  note "Manifest file with files that are maniskipped";
  spew( "MANIFEST",      "file_a\n" );
  spew( "MANIFEST.SKIP", "file_a\n" );
  spew( "file_a",        "Some content" );

  my (@missing);
  my ( $out, $err ) = catch_warning( sub { @missing = manicheck() } );
  cmp_ok( scalar @missing, '==', 0, 'skipfile doesnt show file_a as missing' )
    or do {
    note $_ for @missing;
    };
  cmp_ok( $err, 'eq', '', 'no warnings' );
};

