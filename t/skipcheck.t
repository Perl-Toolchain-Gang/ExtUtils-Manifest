use strict;
use warnings;

use lib 't/lib';
use ManifestTest qw( catch_warning canon_warning spew slurp runtemp );
use ExtUtils::Manifest qw( skipcheck );
use Cwd qw();
use Test::More tests => 37;

# Yes, most of these cases do the same thing.
# skipcheck doesn't do anything in any of the below cases.
runtemp "skipcheck.emptydir" => sub {
  note "Skipcheck an empty dir";
  my (@items);
  my ( $exit, $warn ) = catch_warning sub { @items = skipcheck };
  ok( !@items, "no items" );
  is( $warn, '', 'no warning' );
};

runtemp "skipcheck.emptymanifest" => sub {
  note "Skipcheck a dir with empty manifest";
  spew( "MANIFEST", "" );
  my (@items);
  my ( $exit, $warn ) = catch_warning sub { @items = skipcheck };
  ok( !@items, "no items" );

  is( $warn, '', 'no warning' );
};

runtemp "skipcheck.selfmanifest" => sub {
  note "Skipcheck a dir with self-containing manifest";
  spew( "MANIFEST", "MANIFEST" );
  my (@items);
  my ( $exit, $warn ) = catch_warning sub { @items = skipcheck };
  ok( !@items, "no items" );
  is( $warn, '', 'no warning' );
};

runtemp "skipcheck.fileonly" => sub {
  note "Skipcheck a dir with a non-manifest file";
  spew( "foo", "garbage" );
  my (@items);
  my ( $exit, $warn ) = catch_warning sub { @items = skipcheck };
  ok( !@items, "no items" );
  is( $warn, '', 'no warning' );
};

runtemp "skipcheck.extrafile" => sub {
  note "Skipcheck a dir with a manifest missing a file";
  spew( "MANIFEST", "MANIFEST" );
  spew( "foo",      "garbage" );
  my (@items);
  my ( $exit, $warn ) = catch_warning sub { @items = skipcheck };
  ok( !@items, "no items" );
  is( $warn, '', 'no warning' );
};

runtemp "skipcheck.emptymanifest.emptyskip" => sub {
  note "Skipcheck a dir with empty manifest and empty skipfile";
  spew( "MANIFEST",      "" );
  spew( "MANIFEST.SKIP", "" );
  my (@items);
  my ( $exit, $warn ) = catch_warning sub { @items = skipcheck };
  ok( !@items, "no items" );

  is( $warn, '', 'no warning' );
};

runtemp "skipcheck.selfmanifest.emptyskip" => sub {
  note "Skipcheck a dir with self-containing manifest and empty skipfile";
  spew( "MANIFEST",      "MANIFEST" );
  spew( "MANIFEST.SKIP", "" );

  my (@items);
  my ( $exit, $warn ) = catch_warning sub { @items = skipcheck };
  ok( !@items, "no items" );
  is( $warn, '', 'no warning' );
};

runtemp "skipcheck.fileonly.emptyskip" => sub {
  note "Skipcheck a dir with a non-manifest file and empty skipfile";
  spew( "foo",           "garbage" );
  spew( "MANIFEST.SKIP", "" );

  my (@items);
  my ( $exit, $warn ) = catch_warning sub { @items = skipcheck };
  ok( !@items, "no items" );
  is( $warn, '', 'no warning' );
};

runtemp "skipcheck.extrafile.emptyskip" => sub {
  note "Skipcheck a dir with a manifest missing a file and empty skipfile";
  spew( "MANIFEST",      "MANIFEST" );
  spew( "foo",           "garbage" );
  spew( "MANIFEST.SKIP", "" );

  my (@items);
  my ( $exit, $warn ) = catch_warning sub { @items = skipcheck };
  ok( !@items, "no items" );
  is( $warn, '', 'no warning' );
};

runtemp "skipcheck.selfmanifest.selfskip" => sub {
  note "Skipcheck a dir with self-containing manifest and self-containing skipfile";
  spew( "MANIFEST",      "MANIFEST" );
  spew( "MANIFEST.SKIP", "MANIFEST.SKIP" );

  my (@items);
  my ( $exit, $warn ) = catch_warning sub { @items = skipcheck };
  cmp_ok( scalar @items, '==', 1, "Exactly one skip result" );
  cmp_ok( uc $items[0], 'eq', 'MANIFEST.SKIP', "report skipping MANIFEST.SKIP" );
  like( canon_warning($warn), qr/^Skipping MANIFEST\.SKIP\|/i, 'Warning expected' );
};

runtemp "skipcheck.selfmanifest.selfskip.quiet" => sub {
  note "Skipcheck a dir with self-containing manifest and self-containing skipfile when quietened";
  spew( "MANIFEST",      "MANIFEST" );
  spew( "MANIFEST.SKIP", "MANIFEST.SKIP" );

  my (@items);
  my ( $exit, $warn ) = catch_warning sub {
    local $ExtUtils::Manifest::Quiet = 1;
    @items = skipcheck;
  };
  cmp_ok( scalar @items, '==', 1, "Exactly one skip result" );
  cmp_ok( uc $items[0], 'eq', 'MANIFEST.SKIP', "report skipping MANIFEST.SKIP" );
  is( $warn, '', 'Warning silenced' );
};

runtemp "skipcheck.relative_paths" => sub {
  note "make sure MANIFEST.SKIP uses relative paths in regex";
SKIP: {
    ok( ( mkdir 'moretest', 0777 ), 'created test dir' ) or skip "Cant create dir", 4;
    eval { spew( [ 'moretest', 'quux' ] => 'Some content' ); 1 } or skip "Cant create file in dir", 3;
    spew( 'MANIFEST',      '' );
    spew( 'MANIFEST.SKIP', "^moretest/q\n" );
    my (@items);
    my ( $exit, $warn ) = catch_warning sub { @items = skipcheck };
    cmp_ok( scalar @items, '==', 1, "Exactly one skip result" );
    cmp_ok( lc $items[0], 'eq', 'moretest/quux', "report skipping moretest/quux" );
    like( canon_warning($warn), qr/^Skipping moretest\/quux\|/i, 'Warning expected' );
  }
};

runtemp "skipcheck.include_default" => sub {
  note "ensuring #include_default works in skipcheck";
  spew( 'MANIFEST',        '' );
  spew( 'Makefile',        '' );
  spew( 'mymanifest.skip', "Makefile\n" );
  spew( 'MANIFEST.SKIP',   "#!include_default" );

  my (@items);
  my ( $exit, $warn ) = catch_warning sub {
    local $ExtUtils::Manifest::DEFAULT_MSKIP = File::Spec->catfile( Cwd::getcwd, 'mymanifest.skip' );
    @items = skipcheck;
  };
  cmp_ok( scalar @items, '==', 1,          'Exactly one skip result' );
  cmp_ok( lc $items[0],  'eq', 'makefile', "report skipping Makefile" );
  like( canon_warning($warn), qr/^Skipping Makefile\|/i, 'Warning expected' );

};

runtemp "skipcheck.include" => sub {
  note "ensuring #include works in skipcheck";

  spew( 'MANIFEST',        'MANIFEST.SKIP' );
  spew( 'Makefile',        'content' );
  spew( 'mymanifest.skip', "Makefile\n" );
  spew( 'MANIFEST.SKIP',   "#!include mymanifest.skip" );

  my (@items);
  my ( $exit, $warn ) = catch_warning sub { @items = skipcheck };
  cmp_ok( scalar @items, '==', 1, 'Exactly one skip result' ) or note explain \@items;
  cmp_ok( lc $items[0], 'eq', 'makefile', "report skipping Makefile" );
  like( canon_warning($warn), qr/^Skipping Makefile\|/i, 'Warning expected' );

};
runtemp "skipcheck.include_dir" => sub {
  note "ensuring #include works in skipcheck with a file in a dir";

  spew( 'MANIFEST', 'MANIFEST.SKIP' );
  mkdir "mantest";

  spew( 'Makefile', 'content' );
  spew( [ 'mantest', 'mymanifest.skip' ], "Makefile\n" );
  spew( 'MANIFEST.SKIP', "#!include mantest/mymanifest.skip" );

  my (@items);
  my ( $exit, $warn ) = catch_warning sub { @items = skipcheck };
  cmp_ok( scalar @items, '==', 1, 'Exactly one skip result' ) or note explain \@items;
  cmp_ok( lc $items[0], 'eq', 'makefile', "report skipping Makefile" );
  like( canon_warning($warn), qr/^Skipping Makefile\|/i, 'Warning expected' );

};

