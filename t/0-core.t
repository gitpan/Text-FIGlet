BEGIN{
	$|=1;
	my $t = 6;
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
  like($@, qr/\[(?:\.\\)?foo.flc\]/,'WIN32 FILEPARSE RELATIVE');
  eval{ Text::FIGlet->new("_\\"=>1, -C=>'\bar\qux.flc') };
  like($@, qr/\[\\bar\\qux.flc\]/,  'WIN32 FILEPARSE ABSOLUTE');

#}Return things to normal {
  File::Basename::fileparse_set_fstype($FS);
  @File::Spec::ISA = @WASA;
}


#Avoid "chicken & egg" of verifying -m0 before core by testing single chars
#3
my $txt1 = <<'ASCII';
 /\/|
|/\/ 
     
     
     
     
ASCII
eq_or_diff scalar $font->figify(-A=>"~"), $txt1, "ASCII ~";


#4
my $txt2 = <<'ANSI';
/\___/\
\  _  /
| (_) |
/ ___ \
\/   \/
       
ANSI
eq_or_diff scalar $font->figify(-A=>chr(164)), $txt2, "ANSI [currency]";


#5
$font = Text::FIGlet->new(-D=>1, -m=>0);
my $txt3 = <<'DEUTCSH';
  ___ 
 / _ \
| |/ /
| |\ \
| ||_/
|_|   
DEUTCSH
eq_or_diff scalar $font->figify(-A=>'~'), $txt3, "DEUTSCH s-z";

#6
my $txt6 = <<'NEWLINE';
 __  __ 
|  \/  |
| |\/| |
| |  | |
|_|  |_|
        
       
 _   _ 
| | | |
| |_| |
 \__,_|
       
NEWLINE
eq_or_diff scalar $font->figify(-A=>"M\nu"), $txt6, "-A=>\\n";
