use ExtUtils::MakeMaker;
WriteMakefile(
	      NAME	   => 'Text::FIGlet',
	      VERSION_FROM => 'lib/Text/FIGlet.pm',
	      PREREQ_PM    =>{'Test::Differences' => undef},  #Test dependency
	      PL_FILES     =>{'minifig.PL'=>'bin/minifig.pl',
			      'shebang.PL'=>[qw(bin/charmap.pl
				                bin/figlet.pl
				                bin/showfigfonts.pl)] },
	      EXE_FILES    =>[ glob('bin/*.pl') ]
	     );
