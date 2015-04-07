use strict;
use warnings;

use lib 't/lib';
use ManifestTest qw( catch_warning canon_warning spew runtemp );
use ExtUtils::Manifest qw( filecheck );
use Test::More tests => 11;

runtemp "filecheck.emptydir" => sub {
  note "Empty dir check";
  my (@extra);
  my ( $out, $warning ) = catch_warning sub { @extra = filecheck() };
  ok( !@extra, 'no extra files' ) or do {
    diag $_ for @extra;
  };
};

runtemp "filecheck.blank_manifest" => sub {
  note "Blank Manifest File";
  spew( "MANIFEST", "" );
  my (@extra);
  my ( $out, $warning ) = catch_warning sub { @extra = filecheck() };
  ok( @extra, 'filecheck vs blank MANIFEST == extra files' );
  is( canon_warning($warning), "Not in MANIFEST: MANIFEST|", "Manifest warns about not being in itself" );
};

runtemp "filecheck.self_manifest" => sub {
  note "Self-Containing Manifest File";
  spew( "MANIFEST", "MANIFEST" );
  my (@extra);
  my ( $out, $warning ) = catch_warning sub { @extra = filecheck() };
  ok( !@extra, 'filecheck vs self-containing MANIFEST no extras' );
  is( $warning, '', "No warnings" );
};

runtemp "filecheck.surplus_file" => sub {
  note "A Surplus file not in the manifest";
  spew( "MANIFEST",        "MANIFEST" );
  spew( "not_in_manifest", "Content" );
  my (@extra);
  my ( $out, $warning ) = catch_warning sub { @extra = filecheck() };
  ok( @extra, 'Extra files reported' );
  is( lc( $extra[0] ), 'not_in_manifest', "File reported missing" );
  is( canon_warning($warning), "Not in MANIFEST: not_in_manifest|", "Manifest warns about missing file" );
};

runtemp "filecheck.surplus_file_nowarnings" => sub {
  note "A Surplus file not in the manifest with warnings disabled";
  spew( "MANIFEST",        "MANIFEST" );
  spew( "not_in_manifest", "Content" );
  my (@extra);
  my ( $out, $warning ) = catch_warning sub {
    local $ExtUtils::Manifest::Quiet = 1;
    @extra = filecheck();
  };
  ok( @extra, 'Extra files reported' );
  is( lc( $extra[0] ), 'not_in_manifest', "File reported missing" );
  is( $warning, '', "No Warning" );
};
