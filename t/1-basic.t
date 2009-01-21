BEGIN{ exit -1 if $] < 5.006; eval "use Test::Simple tests => 5; use Test::Differences";}
use Text::FIGlet;

$ENV{FIGLIB} = 'share';
my $font = Text::FIGlet->new();

#1
ok( defined(my $ctrl = Text::FIGlet->new(-C=>'upper.flc')), 'FIGLIB');


#2
my $txt2 =<<'CTRL';
 _   _  _____  _      _       ___   __        __  ___   ____   _      ____  
| | | || ____|| |    | |     / _ \  \ \      / / / _ \ |  _ \ | |    |  _ \ 
| |_| ||  _|  | |    | |    | | | |  \ \ /\ / / | | | || |_) || |    | | | |
|  _  || |___ | |___ | |___ | |_| |   \ V  V /  | |_| ||  _ < | |___ | |_| |
|_| |_||_____||_____||_____| \___/     \_/\_/    \___/ |_| \_\|_____||____/ 
                                                                            
CTRL
#eq_or_diff scalar $font->figify(-A=>$ctrl->tr('Hello World')), $txt2, "CTRL";
eq_or_diff scalar $ctrl->tr('Hello World'), 'HELLO WORLD', "CTRL";


#3
my $txt3 = <<'CENTER';
                       ____               _               
                      / ___|  ___  _ __  | |_   ___  _ __ 
                     | |     / _ \| '_ \ | __| / _ \| '__|
                     | |___ |  __/| | | || |_ |  __/| |   
                      \____| \___||_| |_| \__| \___||_|   
                                                          
CENTER
eq_or_diff scalar $font->figify(-A=>'Center',-x=>'c'), $txt3, "CENTER";

#4
my $txt4 = <<'RIGHT';
                                                    ____   _         _      _   
                                                   |  _ \ (_)  __ _ | |__  | |_ 
                                                   | |_) || | / _` || '_ \ | __|
                                                   |  _ < | || (_| || | | || |_ 
                                                   |_| \_\|_| \__, ||_| |_| \__|
                                                              |___/             
RIGHT
eq_or_diff scalar $font->figify(-A=>'Right',-x=>'r'), $txt4, "RIGHT";

#5
my $txt5 = <<'R2L';
                   _     __        _          _     _    _             _  ____  
                  | |_  / _|  ___ | |   ___  | |_  | |_ | |__    __ _ (_)|  _ \ 
                  | __|| |_  / _ \| |  / _ \ | __| | __|| '_ \  / _` || || |_) |
                  | |_ |  _||  __/| | | (_) || |_  | |_ | | | || (_| || ||  _ < 
                   \__||_|   \___||_|  \___/  \__|  \__||_| |_| \__, ||_||_| \_\
                                                                |___/           
R2L
eq_or_diff scalar $font->figify(-A=>'Right to left',-X=>'R'), $txt5, "R2L";
