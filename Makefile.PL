use ExtUtils::MakeMaker;

WriteMakefile(
	      NAME	   => 'Text::FIGlet',
	      VERSION_FROM => 'lib/Text/FIGlet.pm',
	      PL_FILES     =>{'bin/minifig.PL'=>'bin/minifig.pl' },
	      EXE_FILES    =>[ glob('bin/*.pl'), 'bin/minifig.pl' ],
	      ($] < 5.006 ? () :#Test dependency bypass
	       (PREREQ_PM    =>{'Test::Differences' => undef})),
	     );

#To bypass make test: t/*.t for perl 5.005
rename('t', 'TEST') if $] < 5.006;
