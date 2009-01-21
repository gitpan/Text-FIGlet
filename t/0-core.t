BEGIN{ exit -1 if $] < 5.006; eval "use Test::Simple tests => 3; use Test::Differences";}
use Text::FIGlet;

#0 imlicit $ENV test
$ENV{FIGLIB} = 'share';
my $font = Text::FIGlet->new();


#1
my $txt1 = <<'ASCII';
 /\/| _   _        _  _         __        __              _      _  /\/|
|/\/ | | | |  ___ | || |  ___   \ \      / /  ___   _ __ | |  __| ||/\/ 
     | |_| | / _ \| || | / _ \   \ \ /\ / /  / _ \ | '__|| | / _` |     
     |  _  ||  __/| || || (_) |   \ V  V /  | (_) || |   | || (_| |     
     |_| |_| \___||_||_| \___/     \_/\_/    \___/ |_|   |_| \__,_|     
                                                                        
ASCII
eq_or_diff scalar $font->figify(-A=>"~Hello World~", -m=>-1), $txt1, "ASCII";


#2
my $txt2 = <<'ANSI';
/\___/\
\  _  /
| (_) |
/ ___ \
\/   \/
       
ANSI
eq_or_diff scalar $font->figify(-A=>chr(164), -m=>-1), $txt2, "ANSI";


#3
$font = Text::FIGlet->new(-D=>1);
my $txt3 = <<'DEUTCSH';
 _   _  _   _  _   _  _   _  _   _  _   _   ___ 
(_)_(_)(_)_(_)(_) (_)(_)_(_)(_)_(_)(_) (_) / _ \
  /_\   / _ \ | | | | / _` | / _ \ | | | || |/ /
 / _ \ | |_| || |_| || (_| || (_) || |_| || |\ \
/_/ \_\ \___/  \___/  \__,_| \___/  \__,_|| ||_/
                                          |_|   
DEUTCSH
eq_or_diff scalar $font->figify(-A=>'[\\]{|}~', -m=>-1), $txt3, "DEUTSCH";