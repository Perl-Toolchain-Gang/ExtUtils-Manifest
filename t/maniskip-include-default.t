use strict;
use warnings;

use Test::More tests => 3;
use ExtUtils::Manifest qw( maniskip );
use File::Temp qw( tempdir );
use Cwd qw( abs_path );
use Carp qw( croak );

# ABSTRACT: Ensure include-default is memory only
my $cwd = abs_path('.');
{
    my $tempdir = tempdir(
        "EUM-include-default-XXXXXX",
        TMPDIR   => 1,
        CLEANUP  => !$ENV{PRESERVE_TEMPDIR},
    );
    note("Working in $tempdir");
    chdir $tempdir or croak "Can't chdir to '$tempdir'";

    {
        open my $fh, ">:unix", "MANIFEST.SKIP" or croak "Couldn't open MANIFEST.SKIP: $!";
        print $fh qq[#!include_default] or croak "Couldn't write to MANIFEST.SKIP: $!";
        close $fh                       or croak "Couldn't write to MANIFEST.SKIP: $!";
    }

    my $skipchk = maniskip();

    my $skipcontents = do {
        open my $fh, "<:unix", "MANIFEST.SKIP" or croak "Couldn't open MANIFEST.SKIP: $!";
        local $/;
        <$fh>;
    };

    unlike( $skipcontents, qr/#!start\s*included/, 'include_default not expanded on disk' );

    ok( $skipchk->('Makefile'),     'Makefile still skipped by default' );
    ok( !$skipchk->('Makefile.PL'), 'Makefile.PL still not skipped by default' );

    chdir $cwd or croak "Couldn't return to $cwd: $!";
}
done_testing;
