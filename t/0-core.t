BEGIN{
	$|=1;
	my $t = 5;
	$] < 5.006 ? do{ print "1..$t\n"; require 't/5005-lib.pm'} :
	eval "use Test::More tests => $t; use Test::Differences"; }
use Text::FIGlet;

#0 implicit $ENV test
$ENV{FIGLIB} = 'share';
my $font = Text::FIGlet->new();


#1&2
{#Fake windows environment
  my $FS = File::Basename::fileparse_set_fstype('MSWin32');
  my@WASA=@File::Spec::ISA;
  require "File/Spec/Win32.pm";
  @File::Spec::ISA = ("File::Spec::Win32");

#}Tests {
  eval{ Text::FIGlet->new("_\\"=>1, -C=>'.\foo.flc') };
  #wish i could say that everyone was wrong
  like($@, qr/\[(?:\.\\)?foo.flc\]/,'Win32 fileparse hack');
  eval{ Text::FIGlet->new("_\\"=>1, -C=>'\bar\qux.flc') };
  like($@, qr/\[\\bar\\qux.flc\]/,  'Win32 fileparse hack');

#}Return things to normal {
  File::Basename::fileparse_set_fstype($FS);
  @File::Spec::ISA = @WASA;
}


#3
my $txt1 = <<'ASCII';
 /\/| _   _        _  _         __        __              _      _  /\/|
|/\/ | | | |  ___ | || |  ___   \ \      / /  ___   _ __ | |  __| ||/\/ 
     | |_| | / _ \| || | / _ \   \ \ /\ / /  / _ \ | '__|| | / _` |     
     |  _  ||  __/| || || (_) |   \ V  V /  | (_) || |   | || (_| |     
     |_| |_| \___||_||_| \___/     \_/\_/    \___/ |_|   |_| \__,_|     
                                                                        
ASCII
eq_or_diff scalar $font->figify(-A=>"~Hello World~", -m=>-1), $txt1, "ASCII";


#4
my $txt2 = <<'ANSI';
/\___/\
\  _  /
| (_) |
/ ___ \
\/   \/
       
ANSI
eq_or_diff scalar $font->figify(-A=>chr(164), -m=>-1), $txt2, "ANSI";


#5
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