use strict;
use warnings;

use lib 't/lib';
use ManifestTest qw( catch_warning canon_warning spew runtemp );
use ExtUtils::Manifest qw( maniadd maniread maniskip skipcheck mkmanifest );
use Test::More;

my $filenames = {
  space                 => 'foo bar',
  space_quote           => 'foo\' baz\'quux',
  space_backslash       => 'foo bar\\baz',
  space_quote_backslash => 'foo bar\\baz\'quux',
  quoted_string         => q{'foo quoted name.txt'},    # https://rt.perl.org/Ticket/Display.html?id=122415
};

my $LAST_ERROR;

# Return 1 if it fatalled, undef otherwise.
# Its almost bash!
# !fatal = expect not fatal.
# fatal  = expect fatal
sub fatal(&) {
  my ($code) = @_;
  my ($ok);
  {
    local $@;
    $ok = eval { $code->(); 1 };
    $LAST_ERROR = $@;
  }
  return !$ok;
}

plan tests => ( scalar keys %{$filenames} ) * 8;

note " \nMaking sure maniadd of file works correctly unusually named files";
for my $testname ( sort keys %{$filenames} ) {
  my $filename = $filenames->{$testname};

  runtemp "01-filenames.maniadd.$testname" => sub {
    note "Making sure maniadd of file works correctly with file named: <$filename>";
    spew( "MANIFEST", "\n" );
    maniadd( { $filename => $testname } );
    my $read = maniread;
    is( scalar keys %{$read}, 1, "One file in manifest" );
    ok( exists $read->{$filename}, "file for test $testname ( $filename ) exists" );
    is( $read->{$filename}, $testname, "comment for test $testname ( $filename ) extracted correctly" );
  };
}

note " \nMaking sure skipcheck works correctly unusually named files";
for my $testname ( sort keys %{$filenames} ) {
  my $filename = $filenames->{$testname};

  runtemp "01-filenames.skipcheck.$testname" => sub {
    note "Making sure skipcheck can hide file with file named: <$filename> and regex ^'?foo";
  SKIP: {
      spew( "MANIFEST",      "\n" );
      spew( "MANIFEST.SKIP", "^'?foo\nMANIFEST.SKIP\nMANIFEST.bak\n" );

      skip "Cant create $filename: $LAST_ERROR", 1 if fatal { spew( $filename, $testname ) };
      my $warning = catch_warning sub { skipcheck };
      like( $warning, qr/Skipping \Q$filename\E/, "skipcheck reports elective skipped files" );
    }

  };
}

note " \nMaking sure mkmanifest correctly skips unusually named files";
for my $testname ( sort keys %{$filenames} ) {
  my $filename = $filenames->{$testname};

  runtemp "01-filenames.mkmanifest.skip_$testname" => sub {
    note "Making sure mkmanifest can hide file with file named: <$filename> and regex ^'?foo";
  SKIP: {
      spew( "MANIFEST",      "\n" );
      spew( "MANIFEST.SKIP", "^'?foo\nMANIFEST.SKIP\nMANIFEST.bak\n" );

      skip "Cant create $filename: $LAST_ERROR", 2 if fatal { spew( $filename, $testname ) };

      my $warning = catch_warning sub { mkmanifest };
      my $read = maniread;
      is( scalar keys %{$read}, 1, "One file in manifest" );
      my ( $file, ) = keys %{$read};

      # Case insensitive for VMS
      is( lc($file), "manifest", "Only manifest seen" );
    }
  };
}
note " \nMaking sure mkmanifest correctly includes unusually named files";
for my $testname ( sort keys %{$filenames} ) {
  my $filename = $filenames->{$testname};

  runtemp "01-filenames.mkmanifest.include_$testname" => sub {
    note "Making sure mkmanifest include a file named: <$filename>";
  SKIP: {
      spew( "MANIFEST",      "\n" );
      spew( "MANIFEST.SKIP", "MANIFEST.SKIP\nMANIFEST.bak\n" );
      skip "Cant create $filename: $LAST_ERROR", 2 if fatal { spew( $filename, $testname ) };

      my $warning = catch_warning sub { mkmanifest };
      my $read = maniread;
      is( scalar keys %{$read}, 2, "two files in manifest" );

      # Case insensitive for VMS
      my ( @got ) = sort map { lc($_) } keys %{$read};
      my ( @expected ) = sort map { lc($_) } 'MANIFEST', $filename;

      is_deeply( \@got, \@expected, "Both files returned undefiled" );
    }
  };
}
