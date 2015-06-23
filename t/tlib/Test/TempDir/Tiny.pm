use 5.006;
use strict;
use warnings;

package Test::TempDir::Tiny;
# ABSTRACT: Temporary directories that stick around when tests fail

our $VERSION = '0.005';

use Exporter 5.57 qw/import/;
our @EXPORT = qw/tempdir in_tempdir/;

use Carp qw/confess/;
use Cwd qw/abs_path/;
use Errno qw/EEXIST ENOENT/;
{
    no warnings 'numeric'; # loading File::Path has non-numeric warnings on 5.8
    use File::Path 2.01 qw/remove_tree/;
}
use File::Spec::Functions qw/catdir/;
use File::Temp;

my ( $ROOT_DIR, $TEST_DIR, %COUNTER );
my ( $ORIGINAL_PID, $ORIGINAL_CWD, $TRIES, $DELAY, $SYSTEM_TEMP ) =
  ( $$, abs_path("."), 100, 50 / 1000, 0 );

=func tempdir

    $dir = tempdir();          # .../default_1/
    $dir = tempdir("label");   # .../label_1/

Creates a directory underneath a test-file-specific temporary directory and
returns the absolute path to it in platform-native form (i.e. with backslashes
on Windows).

The function takes a single argument as a label for the directory or defaults
to "default". An incremental counter value will be appended to allow a label to
be used within a loop with distinct temporary directories:

    # t/foo.t

    for ( 1 .. 3 ) {
        tempdir("in loop");
    }

    # creates:
    #   ./tmp/t_foo_t/in_loop_1
    #   ./tmp/t_foo_t/in_loop_2
    #   ./tmp/t_foo_t/in_loop_3

If the label contains any characters besides alphanumerics, underscore
and dash, they will be collapsed and replaced with a single underscore.

    $dir = tempdir("a space"); # .../a_space_1/
    $dir = tempdir("a!bang");  # .../a_bang_1/

The test-file-specific directory and all directories within it will be cleaned
up with an END block if the current test file passes tests.

=cut

sub tempdir {
    my $label = defined( $_[0] ) ? $_[0] : 'default';
    $label =~ tr{a-zA-Z0-9_-}{_}cs;

    _init() unless $ROOT_DIR && $TEST_DIR;
    my $suffix = ++$COUNTER{$label};
    my $subdir = catdir( $TEST_DIR, "${label}_${suffix}" );
    mkdir $subdir or confess("Couldn't create $subdir: $!");
    return $subdir;
}

=func in_tempdir

    in_tempdir "label becomes name" => sub {
        my $cwd = shift;
        # this happens in tempdir
    };

Given a label and a code reference, creates a temporary directory based on the
label (following the rules of L</tempdir>), changes to that directory, runs the
code, then changes back to the original directory.

The temporary directory path is given as an argument to the code reference.
The code runs in the same context as C<in_tempdir> and C<in_tempdir> returns
the return value(s) from the code.

When the code finishes (even if it dies), C<in_tempdir> will change back to the
original directory if it can, to the root if it can't, and will rethrow any
fatal errors.

=cut

sub in_tempdir {
    my ( $label, $code ) = @_;
    my $wantarray = wantarray;
    my $cwd       = abs_path(".");
    my $tempdir   = tempdir($label);

    chdir $tempdir or die "Can't chdir to '$tempdir'";
    my (@ret);
    my $ok = eval {
        if ($wantarray) {
            @ret = $code->($tempdir);
        }
        elsif ( defined $wantarray ) {
            $ret[0] = $code->($tempdir);
        }
        else {
            $code->($tempdir);
        }
        1;
    };
    my $err = $@;
    chdir $cwd or chdir "/" or die "Can't chdir to either '$cwd' or '/'";
    die $err if !$ok;
    return $wantarray ? @ret : $ret[0];
}

sub _inside_t_dir {
    -d "../t" && abs_path(".") eq abs_path("../t");
}

sub _init {

    my $DEFAULT_ROOT = catdir( $ORIGINAL_CWD, "tmp" );

    if ( -d 't' && ( -w $DEFAULT_ROOT || -w '.' ) ) {
        $ROOT_DIR = $DEFAULT_ROOT;
    }
    elsif ( _inside_t_dir() && ( -w '../$DEFAULT_ROOT' || -w '..' ) ) {
        $ROOT_DIR = catdir( $ORIGINAL_CWD, "..", "tmp" );
    }
    else {
        $ROOT_DIR = File::Temp::tempdir( TMPDIR => 1, CLEANUP => 1 );
        $SYSTEM_TEMP = 1;
    }

    # TEST_DIR is based on .t path under ROOT_DIR
    ( my $dirname = $0 ) =~ tr{:\\/.}{_};
    $TEST_DIR = catdir( $ROOT_DIR, $dirname );

    # If it exists from a previous run, clear it out
    if ( -d $TEST_DIR ) {
        remove_tree( $TEST_DIR, { safe => 0, keep_root => 1 } );
        return;
    }

    # Need to create directory, but constructing nested directories can never
    # be atomic, so we have to retry if the tempdir root gets deleted out from
    # under us (perhaps by a parallel test)

    for my $n ( 1 .. $TRIES ) {
        # Failing to mkdir is OK as long as error is EEXIST
        if ( !mkdir($ROOT_DIR) ) {
            confess("Couldn't create $ROOT_DIR: $!")
              unless $! == EEXIST;
        }

        # Normalize after we know it exists, because abs_path might fail on
        # some platforms if it doesn't exist
        $ROOT_DIR = abs_path($ROOT_DIR);

        # If mkdir succeeds, we're done
        if ( mkdir $TEST_DIR ) {
            # similarly normalize only after we're sure it exists
            $TEST_DIR = abs_path($TEST_DIR);
            return;
        }

        # Anything other than ENOENT is a real error
        if ( $! != ENOENT ) {
            confess("Couldn't create $TEST_DIR: $!");
        }

        # ENOENT means $ROOT_DIR was removed from under us or is not a
        # directory.  Only the latter case is a real error.
        if ( -e $ROOT_DIR && !-d _ ) {
            confess("$ROOT_DIR is not a directory");
        }

        select( undef, undef, undef, $DELAY ) if $n < $TRIES;
    }

    warn "Couldn't create $TEST_DIR in $TRIES tries.\n"
      . "Using a regular tempdir instead.\n";

    # Because fallback isn't under root, we let File::Temp clean it up.
    $TEST_DIR = File::Temp::tempdir( TMPDIR => 1, CLEANUP => 1 );
    return;
}

sub _cleanup {
    return if $ENV{PERL_TEST_TEMPDIR_TINY_NOCLEANUP};
    if ( $ROOT_DIR && -d $ROOT_DIR ) {
        # always cleanup if root is in system temp directory, otherwise
        # only clean up if exiting with non-zero value
        if ( $SYSTEM_TEMP or not $? ) {
            chdir $ORIGINAL_CWD
              or chdir "/"
              or warn "Can't chdir to '$ORIGINAL_CWD' or '/'. Cleanup might fail.";
            remove_tree( $TEST_DIR, { safe => 0 } )
              if -d $TEST_DIR;
        }

        # Remove root unless it's a symlink, which a user might create to
        # force it to another drive.  Removal will fail if there are any
        # children, but we ignore errors as other tests might be running
        # in parallel and have tempdirs there.
        rmdir $ROOT_DIR unless -l $ROOT_DIR;
    }
}

# for testing
sub _root_dir { return $ROOT_DIR }

END {
    # only clean up in original process, not children
    if ( $$ == $ORIGINAL_PID ) {
        # our clean up must run after Test::More sets $? in its END block
        require B;
        push @{ B::end_av()->object_2svref }, \&_cleanup;
    }
}

1;

=head1 SYNOPSIS

    # t/foo.t
    use Test::More;
    use Test::TempDir::Tiny;

    # default tempdirs
    $dir = tempdir();          # ./tmp/t_foo_t/default_1/
    $dir = tempdir();          # ./tmp/t_foo_t/default_2/

    # labeled tempdirs
    $dir = tempdir("label");   # ./tmp/t_foo_t/label_1/
    $dir = tempdir("label");   # ./tmp/t_foo_t/label_2/

    # labels with spaces and non-word characters
    $dir = tempdir("bar baz")  # ./tmp/t_foo_t/bar_baz_1/
    $dir = tempdir("!!!bang")  # ./tmp/t_foo_t/_bang_1/

    # run code in a temporary directory
    in_tempdir "label becomes name" => sub {
        my $cwd = shift;
        # do stuff in a tempdir
    };

=head1 DESCRIPTION

This module works with L<Test::More> to create temporary directories that stick
around if tests fail.

It is loosely based on L<Test::TempDir>, but with less complexity, greater
portability and zero non-core dependencies.  (L<Capture::Tiny> is recommended
for testing.)

The L</tempdir> and L</in_tempdir> functions are exported by default.

If the current directory is writable, the root for directories will be
F<./tmp>.  Otherwise, a L<File::Temp> directory will be created wherever
temporary directories are stored for your system.

Every F<*.t> file gets its own subdirectory under the root based on the test
filename, but with slashes and periods replaced with underscores.  For example,
F<t/foo.t> would get a test-file-specific subdirectory F<./tmp/t_foo_t/>.
Directories created by L</tempdir> get put in that directory.  This makes it
very easy to find files later if tests fail.

The test-file-specific name is consistent from run-to-run.  If an old directory
already exists, it will be removed.

When the test file exits, if all tests passed, then the test-file-specific
directory is recursively removed.

If a test failed and the root directory is F<./tmp>, the test-file-specific
directory sticks around for inspection.  (But if the root is a L<File::Temp>
directory, it is always discarded).

If nothing is left in F<./tmp> (i.e. no other test file failed), then F<./tmp>
is cleaned up as well (unless it's a symlink).

This module attempts to avoid race conditions due to parallel testing.  In
extreme cases, the test-file-specific subdirectory might be created as a
regular L<File::Temp> directory rather than in F<./tmp>.  In such a case,
a warning will be issued.

=head1 ENVIRONMENT

=head2 C<PERL_TEST_TEMPDIR_TINY_NOCLEANUP>

When this environment variable is true, directories will not be cleaned up,
even if tests pass.

=head1 SEE ALSO

=for :list
* L<File::Temp>
* L<Path::Tiny>

=cut

# vim: ts=4 sts=4 sw=4 et:
