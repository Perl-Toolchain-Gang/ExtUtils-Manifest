use strict;
use warnings;

use Module::Build;
my %prereq = (
              # splitpath(), rel2abs()
              'File::Spec'         => 0.8,
              'File::Basename'     => 0,
             );

my $build = Module::Build->new(
  module_name => 'ExtUtils::Manifest',
  license => 'perl',
  installdirs => 'core',
  requires => \%prereq,
  dist_version_from => 'lib/ExtUtils/Manifest.pm',
  dist_author => ['Randy Kobes <r.kobes@uwinnipeg.ca>'],
  dist_abstract_from => 'lib/ExtUtils/Manifest.pm',
);

$build->add_build_element('SKIP');
$build->create_build_script;

