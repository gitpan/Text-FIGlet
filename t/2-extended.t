use Test::Simple tests => 4;
use Test::Differences;
use Text::FIGlet;

#1
$ENV{FIGLIB} = 'share/';
ok( defined(my $ctrl = Text::FIGlet->new(-C=>'upper.flc')), 'FIGLIB');

#0
$ENV{FIGLIB} = 't/';
my $font = Text::FIGlet->new(-f=>'2');


#2
my $txt2 =<<'CTRL';
 _   _  _____  _      _       ___   __        __  ___   ____   _      ____  
| | | || ____|| |    | |     / _ \  \ \      / / / _ \ |  _ \ | |    |  _ \ 
| |_| ||  _|  | |    | |    | | | |  \ \ /\ / / | | | || |_) || |    | | | |
|  _  || |___ | |___ | |___ | |_| |   \ V  V /  | |_| ||  _ < | |___ | |_| |
|_| |_||_____||_____||_____| \___/     \_/\_/    \___/ |_| \_\|_____||____/ 
                                                                            
CTRL
eq_or_diff scalar $font->figify(-A=>$ctrl->tr('Hello World')), $txt2, "CTRL";


#3
#XX Skip if $] < 5.006;
my $txt3=<<'UNICODE';
 _\_/_ _ \\//
|__  /| | \/ 
  / / | |    
 / /_ | |___ 
/____||_____|
             
UNICODE
eq_or_diff scalar $font->figify(-A=>"\x{17d}\x{13d}", -U=>1), $txt3, "Unicode";


#4
$ctrl = Text::FIGlet->new(-C=>'2.flc');
my $txt4 = <<'-CHAR';
   
   
 o 
/|/
/| 
\| 
-CHAR
eq_or_diff scalar $font->figify(-U=>1, -A=>$ctrl->tr('~')), $txt4, "-CHAR";
