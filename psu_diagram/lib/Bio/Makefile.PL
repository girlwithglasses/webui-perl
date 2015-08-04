require 5.005;
use ExtUtils::MakeMaker;

WriteMakefile(
	      NAME          => 'Bio::PSU',
	      VERSION_FROM  => 'PSU/Base.pm',
	      AUTHOR        => 'Keith James <kdj@sanger.ac.uk>',
	      dist          => {
				TARFLAGS => 'cvf',
				COMPRESS => 'gzip',
				SUFFIX   => 'gz'
			       },
	     );
