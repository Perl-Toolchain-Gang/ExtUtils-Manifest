use strict;
use warnings;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my %prereq = (
              # splitpath(), rel2abs()
              'File::Spec'         => 0.8,
              'File::Basename'     => 0,
             );

my %opts = (
	    NAME		=> 'ExtUtils::Manifest',
	    VERSION_FROM	=> 'lib/ExtUtils/Manifest.pm',
            PL_FILES            => {},
            PREREQ_PM           => \%prereq,
            INSTALLDIRS         => 'perl',
	   );

my $eu_version = $ExtUtils::MakeMaker::VERSION;
if ($eu_version >= 5.43) {
  $opts{ABSTRACT_FROM} = 'lib/ExtUtils/Manifest.pm';
  $opts{AUTHOR} = 'Randy Kobes <r.kobes@uwinnipeg.ca>';
}
if ($eu_version > 6.11) {
  $opts{NO_META} = 1;
}

WriteMakefile(%opts);
