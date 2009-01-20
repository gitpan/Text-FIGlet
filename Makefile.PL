use ExtUtils::MakeMaker;

#To bypass make test: t/*.t for perl 5.005
rename('t', 'TEST') if $] < 5.006;

WriteMakefile(
	      NAME	   => 'Text::FIGlet',
	      VERSION_FROM => 'lib/Text/FIGlet.pm',
	      PL_FILES     =>{'minifig.PL'=>'bin/minifig.pl',
			      'shebang.PL'=>[qw(bin/charmap.pl
				                bin/figlet.pl
				                bin/showfigfonts.pl)] },
	      EXE_FILES    =>[ glob('bin/*.pl') ],
	      ($] < 5.006 ? () :#Test dependency bypass
	       (PREREQ_PM    =>{'Test::Differences' => undef})),
	     );
