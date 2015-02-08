use strict;
use warnings;

use lib 't/lib';
use ManifestTest qw( catch_warning canon_warning spew runtemp );
use ExtUtils::Manifest qw( maniread );
use Test::More tests => 10;

runtemp "maniread.basic_read" => sub {
  note "Basic use of maniread";
  spew( 'MANIFEST', "file_a\nMANIFEST" );
  my $files = maniread();
  is( keys %$files, 2, 'two files found' );
  is( join( ' ', sort { lc($a) cmp lc($b) } keys %$files ), 'file_a MANIFEST', 'both files found' );
};

runtemp "maniread.basic_read_noclobber_context" => sub {
  note "Making sure maniread doesnt clobber \$_";
  my $old = $_;
  $_ = "foo";

  spew( 'MANIFEST', "file_a\nMANIFEST" );
  my $files = maniread();
  is( keys %$files, 2, 'two files found' );
  is( join( ' ', sort { lc($a) cmp lc($b) } keys %$files ), 'file_a MANIFEST', 'both files found' );

  is( $_, 'foo', q{maniread() doesn't clobber $_} );
  $_ = $old;
};

runtemp "maniread.comments" => sub {
  note "Extracting comments from a manifest";

  spew( 'MANIFEST', 'file_a #comment for file a' );
  my $files = maniread();
  is( $files->{file_a}, '#comment for file a', 'mani read found comment' );
};

runtemp "maniread.spaced_file" => sub {
  note "Parsing a manifest with a file with a space in it";

  spew( 'MANIFEST', "'file with space' this is a comment" );
  my $files = maniread();

  is( $files->{'file with space'}, 'this is a comment', 'File name extracted distinctly' );
};

runtemp "maniread.space_and_quote_file" => sub {
  note "Parsing a manifest with a file with literal quotes and spaces";

  spew( 'MANIFEST', "'file\\' with\\' space' this is a comment" );
  my $files = maniread();

  is( $files->{'file\' with\' space'}, 'this is a comment', 'File name extracted distinctly' );
};

runtemp "maniread.space_and_backslash_file" => sub {
  note "Parsing a manifest with a file literal backslashes and spaces";

  spew( 'MANIFEST', "'file\\\\ with\\\\ space' this is a comment" );
  my $files = maniread();

  is( $files->{'file\\ with\\ space'}, 'this is a comment', 'File name extracted distinctly' );
};

# test including a filename which is itself a quoted string
# https://rt.perl.org/Ticket/Display.html?id=122415
runtemp "maniread.quoted_filename" => sub {
  note "Parsing a manifest with a filename which is itself a quoted string";

  spew( 'MANIFEST', "'\\\'file with space\\\'' this is a comment" );
  my $files = maniread();

  is( $files->{'\'file with space\''}, 'this is a comment', 'File name extracted distinctly' );
};
