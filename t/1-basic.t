BEGIN{ exit -1 if $] < 5.006; eval "use Test::Differences";}
use Test::More tests => 7;
use Text::FIGlet;

$ENV{FIGLIB} = 'share';

#1&2
{#Fake windows environment
  my $FS = File::Basename::fileparse_set_fstype('MSWin32');
  my@WASA=@File::Spec::ISA;
  require "File/Spec/Win32.pm";
  @File::Spec::ISA = ("File::Spec::Win32");

#}Tests {
  eval{ Text::FIGlet->new("_\\"=>1, -C=>'.\foo.flc') };
  #wish i could say that everyone was wrong
  like($@, qr/\[(?:\.\\)?foo.flc\]/,      'Win32 fileparse hack');
  eval{ Text::FIGlet->new("_\\"=>1, -C=>'\bar\qux.flc') };
  like($@, qr/\[\\bar\\qux.flc\]/,  'Win32 fileparse hack');

#}Return things to normal {
  File::Basename::fileparse_set_fstype($FS);
  @File::Spec::ISA = @WASA;
}


#3
ok( defined(my $ctrl = Text::FIGlet->new(-C=>'upper.flc')), 'FIGLIB');


#...
my $font = Text::FIGlet->new();


#4
my $txt2 =<<'CTRL';
 _   _  _____  _      _       ___   __        __  ___   ____   _      ____  
| | | || ____|| |    | |     / _ \  \ \      / / / _ \ |  _ \ | |    |  _ \ 
| |_| ||  _|  | |    | |    | | | |  \ \ /\ / / | | | || |_) || |    | | | |
|  _  || |___ | |___ | |___ | |_| |   \ V  V /  | |_| ||  _ < | |___ | |_| |
|_| |_||_____||_____||_____| \___/     \_/\_/    \___/ |_| \_\|_____||____/ 
                                                                            
CTRL
#eq_or_diff scalar $font->figify(-A=>$ctrl->tr('Hello World')), $txt2, "CTRL";
eq_or_diff scalar $ctrl->tr('Hello World'), 'HELLO WORLD', "CTRL";


#5
my $txt3 = <<'CENTER';
                       ____               _               
                      / ___|  ___  _ __  | |_   ___  _ __ 
                     | |     / _ \| '_ \ | __| / _ \| '__|
                     | |___ |  __/| | | || |_ |  __/| |   
                      \____| \___||_| |_| \__| \___||_|   
                                                          
CENTER
eq_or_diff scalar $font->figify(-A=>'Center',-x=>'c'), $txt3, "CENTER";

#6
my $txt4 = <<'RIGHT';
                                                    ____   _         _      _   
                                                   |  _ \ (_)  __ _ | |__  | |_ 
                                                   | |_) || | / _` || '_ \ | __|
                                                   |  _ < | || (_| || | | || |_ 
                                                   |_| \_\|_| \__, ||_| |_| \__|
                                                              |___/             
RIGHT
eq_or_diff scalar $font->figify(-A=>'Right',-x=>'r'), $txt4, "RIGHT";

#7
my $txt5 = <<'R2L';
                   _     __        _          _     _    _             _  ____  
                  | |_  / _|  ___ | |   ___  | |_  | |_ | |__    __ _ (_)|  _ \ 
                  | __|| |_  / _ \| |  / _ \ | __| | __|| '_ \  / _` || || |_) |
                  | |_ |  _||  __/| | | (_) || |_  | |_ | | | || (_| || ||  _ < 
                   \__||_|   \___||_|  \___/  \__|  \__||_| |_| \__, ||_||_| \_\
                                                                |___/           
R2L
eq_or_diff scalar $font->figify(-A=>'Right to left',-X=>'R'), $txt5, "R2L";
