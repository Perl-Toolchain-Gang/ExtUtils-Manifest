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

# $dir = tempdir();          # .../default_1/
# $dir = tempdir("label");   # .../label_1/
sub tempdir {
    my $label = defined( $_[0] ) ? $_[0] : 'default';
    $label =~ tr{a-zA-Z0-9_-}{_}cs;

    _init() unless $ROOT_DIR && $TEST_DIR;
    my $suffix = ++$COUNTER{$label};
    my $subdir = catdir( $TEST_DIR, "${label}_${suffix}" );
    mkdir $subdir or confess("Couldn't create $subdir: $!");
    return $subdir;
}

# in_tempdir "label becomes name" => sub {
#        my $cwd = shift;
#        # this happens in tempdir
#  };

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

# vim: ts=4 sts=4 sw=4 et:
