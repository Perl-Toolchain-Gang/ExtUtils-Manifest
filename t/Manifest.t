#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't' if -d 't';
        unshift @INC, '../lib';
    }
    else {
        unshift @INC, 't/lib';
    }
    $ENV{PERL_MM_MANIFEST_VERBOSE}=1;
}
chdir 't';

use strict;

use Test::More tests => 36;
use Cwd;

use File::Spec;
use File::Path;
use File::Find;
use Config;

my $Is_VMS = $^O eq 'VMS';
my $Is_VMS_noefs = $Is_VMS;
if ($Is_VMS) {
    my $vms_efs = 0;
    if (eval 'require VMS::Feature') {
        $vms_efs = VMS::Feature::current("efs_charset");
    } else {
        my $efs_charset = $ENV{'DECC$EFS_CHARSET'} || '';
        $vms_efs = $efs_charset =~ /^[ET1]/i;
    }
    $Is_VMS_noefs = 0 if $vms_efs;
}

# We're going to be chdir'ing and modules are sometimes loaded on the
# fly in this test, so we need an absolute @INC.
@INC = map { File::Spec->rel2abs($_) } @INC;

# keep track of everything added so it can all be deleted
my %Files;
sub add_file {
    my ($file, $data) = @_;
    $data ||= 'foo';
    $file =~ s/ /^_/g if $Is_VMS_noefs; # escape spaces
    1 while unlink $file;  # or else we'll get multiple versions on VMS
    open( T, '> '.$file) or return;
    binmode T, ':raw'; # no CRLFs please
    print T $data;
    close T;
    return 0 unless -e $file;  # exists under the name we gave it ?
    ++$Files{$file};
}

sub read_manifest {
    open( M, 'MANIFEST' ) or return;
    chomp( my @files = <M> );
    close M;
    return @files;
}

sub catch_warning {
    my $warn = '';
    local $SIG{__WARN__} = sub { $warn .= $_[0] };
    return join('', $_[0]->() ), $warn;
}

sub remove_dir {
    ok( rmdir( $_ ), "remove $_ directory" ) for @_;
}

# use module, import functions
BEGIN {
    use_ok( 'ExtUtils::Manifest',
            qw( mkmanifest
                maniread skipcheck maniadd maniskip) );
}

my $cwd = Cwd::getcwd();

# Just in case any old files were lying around.
rmtree('mantest');

ok( mkdir( 'mantest', 0777 ), 'make mantest directory' );
ok( chdir( 'mantest' ), 'chdir() to mantest' );

my ($res, $warn);
add_file( 'MANIFEST', 'none #none' );

my $files = maniread;
ok( !$files->{wibble},     'MANIFEST in good state' );
maniadd({ wibble => undef });
maniadd({ yarrow => "hock" });
$files = maniread;
is( $files->{wibble}, '',    'maniadd() with undef comment' );
is( $files->{yarrow}, 'hock','          with comment' );

my $manicontents = do {
  local $/;
  open my $fh, "MANIFEST" or die;
  binmode $fh, ':raw';
  <$fh>
};
is index($manicontents, "\015\012"), -1, 'MANIFEST no CRLF';

{
    # EOL normalization in maniadd()

    # move manifest away:
    rename "MANIFEST", "MANIFEST.bak" or die "Could not rename MANIFEST to MANIFEST.bak: $!";
    my $prev_maniaddresult;
    my @eol = ("\012","\015","\015\012");
    # for all line-endings:
    for my $i (0..$#eol) {
        my $eol = $eol[$i];
        #   cp the backup of the manifest to MANIFEST, line-endings adjusted
        my $content = do { local $/; open my $fh, "MANIFEST.bak" or die; <$fh> };
    SPLITTER: for my $eol2 (@eol) {
            if ( index($content, $eol2) > -1 ) {
                my @lines = split /$eol2/, $content;
                pop @lines while $lines[-1] eq "";
                open my $fh, ">", "MANIFEST" or die "Could not open >MANIFEST: $!";
                print $fh map { "$_$eol" } @lines;
                close $fh or die "Could not close: $!";
                last SPLITTER;
            }
        }
        #   try maniadd
        maniadd({eoltest => "end of line normalization test"});
        #   slurp result and compare to previous result
        my $maniaddresult = do { local $/; open my $fh, "MANIFEST" or die; <$fh> };
        if ($prev_maniaddresult) {
            if ( $maniaddresult eq $prev_maniaddresult ) {
                pass "normalization success with i=$i";
            } else {
                require Data::Dumper;
                no warnings "once";
                local $Data::Dumper::Useqq = 1;
                local $Data::Dumper::Terse = 1;
                is Data::Dumper::Dumper($maniaddresult), Data::Dumper::Dumper($prev_maniaddresult), "eol normalization failed with i=$i";
            }
        }
        $prev_maniaddresult = $maniaddresult;
    }
    # move backup over MANIFEST
    rename "MANIFEST.bak", "MANIFEST" or die "Could not rename MANIFEST.bak to MANIFEST: $!";
}

# test including an external manifest.skip file in MANIFEST.SKIP
{
    maniadd({ foo => undef , 'mymanifest.skip' => undef, 'mydefault.skip' => undef});
    add_file('foo' => 'Blah');
    add_file('mymanifest.skip' => "^foo\n");
    add_file('mydefault.skip'  => "^my\n");
    local $ExtUtils::Manifest::DEFAULT_MSKIP =
         File::Spec->catfile($cwd, qw(mantest mydefault.skip));
    my $skip = File::Spec->catfile($cwd, qw(mantest mymanifest.skip));
    add_file('MANIFEST.SKIP' =>  "#!include $skip\n#!include_default");
    my ($res, $warn) = catch_warning( \&skipcheck );
    for (qw(foo mymanifest.skip mydefault.skip)) {
        like( $warn, qr/Skipping \b$_\b/,
              "Skipping $_" );
    }
    ($res, $warn) = catch_warning( \&mkmanifest );
    for (qw(foo mymanifest.skip mydefault.skip)) {
        like( $warn, qr/Removed from MANIFEST: \b$_\b/,
              "Removed $_ from MANIFEST" );
    }
    my $files = maniread;
    ok( exists $files->{yarrow},      'yarrow included in MANIFEST' );
    ok( ! exists $files->{foo},       'foo excluded via mymanifest.skip' );
    ok( ! exists $files->{'mymanifest.skip'},
        'mymanifest.skip excluded via mydefault.skip' );
    ok( ! exists $files->{'mydefault.skip'},
        'mydefault.skip excluded via mydefault.skip' );

    # tests for maniskip
    my $skipchk = maniskip();
    is( $skipchk->('yarrow'), '',
	'yarrow included in MANIFEST' );
    is( $skipchk->('bar'), '',
	'bar included in MANIFEST' );
    $skipchk = maniskip('mymanifest.skip');
    is( $skipchk->('foo'), 1,
	'foo excluded via mymanifest.skip' );
    is( $skipchk->('mymanifest.skip'), '',
        'mymanifest.skip included via mydefault.skip' );
    is( $skipchk->('mydefault.skip'), '',
        'mydefault.skip included via mydefault.skip' );
    $skipchk = maniskip('mydefault.skip');
    is( $skipchk->('foo'), '',
	'foo included via mydefault.skip' );
    is( $skipchk->('mymanifest.skip'), 1,
        'mymanifest.skip excluded via mydefault.skip' );
    is( $skipchk->('mydefault.skip'), 1,
        'mydefault.skip excluded via mydefault.skip' );

    my $extsep = $Is_VMS_noefs ? '_' : '.';
    $Files{"$_.bak"}++ for ('MANIFEST', "MANIFEST${extsep}SKIP");
}

END {
	note "remove all files";
	for my $file ( sort keys %Files ) {
		is(( unlink $file ), 1, "Unlink $file") or note "$!";
	}
	for my $file ( keys %Files ) { 1 while unlink $file; } # all versions

	# now get rid of the parent directory
	ok( chdir( $cwd ), 'return to parent directory' );
	remove_dir( 'mantest' );
}
