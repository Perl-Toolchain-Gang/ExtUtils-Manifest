use strict;
use warnings;

use lib 't/lib';
use ManifestTest qw( catch_warning canon_warning spew slurp runtemp );
use ExtUtils::Manifest qw( mkmanifest );
use Test::More tests => 16;

runtemp "mkmanifest.empty" => sub {
  note "empty mkmanifest dir";

  my ( $res, $warn ) = catch_warning( \&mkmanifest );
  is( canon_warning($warn), "Added to MANIFEST: MANIFEST|", "mkmanifest() displayed its additions" );

  ok( -e 'MANIFEST', 'create MANIFEST file' );
};

runtemp "mkmanifest.existing_file" => sub {
  note "mkmanifest dir with existing content";

  spew( 'foo', 'foo' );

  my ( $res, $warn ) = catch_warning( \&mkmanifest );

  is( canon_warning($warn), "Added to MANIFEST: foo|Added to MANIFEST: MANIFEST|", "mkmanifest() displayed its additions" );

  ok( -e 'MANIFEST', 'create MANIFEST file' );
};

runtemp "mkmanifest.existing_manifest" => sub {
  note "mkmanifest dir with existing MANIFEST file";

  spew( 'MANIFEST', 'foo' );

  my ( $res, $warn ) = catch_warning( \&mkmanifest );

  is( canon_warning($warn), "Added to MANIFEST: MANIFEST|", "mkmanifest() displayed its additions" );

  ok( -e 'MANIFEST',     'create MANIFEST file' );
  ok( -e 'MANIFEST.bak', 'existing MANIFEST file backed up' );
};

runtemp "mkmanifest.custom_filename" => sub {
  note "mkmanifest with custom filename defined";

  local $ExtUtils::Manifest::MANIFEST = 'albatross';

  my ( $res, $warn ) = catch_warning( \&mkmanifest );

  is( canon_warning($warn), "Added to albatross: albatross|", "mkmanifest() displayed its additions to an atypical filename" );
  ok( -e 'albatross', 'atypical manifest \'albatross\' created' );
};

runtemp "mkmanifest.autoadd_spacefiles" => sub {
  note "mkmanifest with a dir with files with spaces in them";
SKIP: {
    eval { spew( "space space", "foo" ); 1 }
      or skip "Cant create spaced file", 2;
    my ( $res, $warn ) = catch_warning( \&mkmanifest );

    is(
      canon_warning($warn),
      "Added to MANIFEST: MANIFEST|Added to MANIFEST: space space|",
      "mkmanifest() displayed its additions"
    );
    ok( -e 'MANIFEST', 'create MANIFEST file' );

  }
};

runtemp "mkmanifest.autoremove" => sub {
  note "mkmanifest removing files on skip list";

  spew( "file_a",        "File A Contents" );
  spew( "file_b",        "File A Contents" );
  spew( "MANIFEST.SKIP", "" );

  my ( $res, $warn ) = catch_warning( \&mkmanifest );

  is(
    canon_warning($warn),
    ( join q[], map { "Added to MANIFEST: $_|" } qw(file_a file_b MANIFEST MANIFEST.SKIP ) ),
    "mkmanifest() displayed its additions"
  );
  ok( -e 'MANIFEST', 'create MANIFEST file' );
  spew( "MANIFEST.SKIP", "MANIFEST.bak\nfile_a" );
  ( $res, $warn ) = catch_warning( \&mkmanifest );

  is( canon_warning($warn), "Removed from MANIFEST: file_a|", "mkmanifest() displayed its removals" );
  ok( -e 'MANIFEST', 'MANIFEST still exists' );
  my @generated = split /\r?\n/, slurp('MANIFEST');
  ok( ( !grep { $_ =~ /file_a/ } @generated ), 'file_a stripped from MANIFEST' );
};

