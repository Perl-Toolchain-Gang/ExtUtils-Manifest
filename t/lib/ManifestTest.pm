use strict;
use warnings;

package ManifestTest;

# ABSTRACT: Manifest Testing Utilities

use Cwd qw( getcwd abs_path );
use File::Temp qw();
use File::Path qw( rmtree );
use Exporter;

our @ISA       = qw( Exporter );
our @EXPORT_OK = qw( catch_warning canon_warning spew runtemp slurp );
my $Is_VMS       = $^O eq 'VMS';
my $Is_VMS_noefs = $Is_VMS;
if ($Is_VMS) {
  my $vms_efs = 0;
  if ( eval 'require VMS::Feature' ) {
    $vms_efs = VMS::Feature::current("efs_charset");
  }
  else {
    my $efs_charset = $ENV{'DECC$EFS_CHARSET'} || '';
    $vms_efs = $efs_charset =~ /^[ET1]/i;
  }
  $Is_VMS_noefs = 0 if $vms_efs;
}

sub runtemp {
  my ( $label, $code ) = @_;
  my $old     = getcwd();
  my $tempdir = File::Temp::tempdir(
    'ManifestTest.' . $label . '.XXXXX',
    DIR     => 't/',
    CLEANUP => 0
  );
  my $abs = abs_path($tempdir);
  chdir $tempdir;
  local $@;
  my $bailed = 1;
  eval { $code->(); $bailed = 0 };
  chdir $old;

  if ( not $bailed ) {
    rmtree( $tempdir, 0, 1 );
    return;
  }
  die "runtemp $label failed: $@\n tempdir left in place\n\t$abs\nstopped ";
}

sub catch_warning {
  my $warn = '';
  local $SIG{__WARN__} = sub { $warn .= $_[0] };
  join( '', $_[0]->() ), $warn;
}

sub canon_warning {
  my ($warn) = @_;
  join( "", map { "$_|" } sort { lc($a) cmp lc($b) } split /\r?\n/, $warn );
}

sub spew {
  my ( $path, $data ) = @_;
  if ( (  ref $path || '' ) eq 'ARRAY' ) {
    require File::Spec;
    $path = File::Spec->catfile(@{$path});
  }
  $data = 'foo' unless defined $data;
  $path =~ s/ /^_/g if $Is_VMS_noefs;    # escape spaces
  1 while unlink $path;                  # or else we'll get multiple versions on VMS
  open my $fh, '>', $path or die "Can't write $path";
  binmode $fh, ':raw';                   # no CRLFs please
  print {$fh} $data;
  close $fh;
  die unless -e $path;                   # exists under the name we gave it ?
}

sub slurp {
  my ($path) = @_;
  $path =~ s/ /^_/g if $Is_VMS_noefs;    # escape spaces
  die "No such file $path" unless -e $path;
  open my $fh, '<', $path or die "Can't read $path";
  binmode $fh, ':raw';
  my $content = do { local $/; <$fh> };
  close $fh;
  return $content;
}

1;

