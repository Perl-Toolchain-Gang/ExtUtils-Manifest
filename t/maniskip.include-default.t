use strict;
use warnings;

use Test::More tests => 3;
use ExtUtils::Manifest qw( maniskip );

# ABSTRACT: Ensure include-default is memory only

use lib 't/tlib';
use Test::TempDir::Tiny qw( in_tempdir );
use ByteSlurper qw( write_bytes read_bytes );

in_tempdir 'no-default-expansions' => sub {

    write_bytes( 'MANIFEST.SKIP', qq[#!include_default] );

    my $skipchk = maniskip();

    my $skipcontents = read_bytes('MANIFEST.SKIP');

    unlike( $skipcontents, qr/#!start\s*included/, 'include_default not expanded on disk' );

    ok( $skipchk->('Makefile'),     'Makefile still skipped by default' );
    ok( !$skipchk->('Makefile.PL'), 'Makefile.PL still not skipped by default' );
};
done_testing;
