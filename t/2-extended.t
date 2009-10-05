BEGIN{ exit -1 if $] < 5.006; eval "use Test::Simple tests => 6; use Test::Differences"; $|=1}
use Text::FIGlet;


#0 implicit -d test
my $font = Text::FIGlet->new(-d=>'t/', -f=>'2', -U=>1);

#1
my $txt1=<<'UNICODE';
 _\_/_ _ \\//
|__  /| | \/ 
  / / | |    
 / /_ | |___ 
/____||_____|
             
UNICODE
eq_or_diff scalar $font->figify(-A=>"\x{17d}\x{13d}", -U=>1), $txt1, "Unicode";


#2
if( $] < 5.006 ){
  ok(-1, "SKIPPING negative character mapping in pre-5.6 perl"); }
else{
  $ctrl = Text::FIGlet->new(-d=>'t/', -C=>'2.flc') ||
    warn("#Failed to load negative character mapping control file: $!\n");
  my $txt2 = <<'-CHAR';
   
   
 o 
/|/
/| 
\| 
-CHAR
  eq_or_diff scalar $font->figify(-U=>1, -A=>$ctrl->tr('~')), $txt2, "-CHAR";
}


#3 Clean TOIlet
$font = Text::FIGlet->new(-d=>'share', -f=>'future');
my $txt3 = <<'CLEAN';
┏━┓┏━┓┏━┓┏━╸┏━┓
┣━┛┣━┫┣━┛┣╸ ┣┳┛
╹  ╹ ╹╹  ┗━╸╹┗╸
CLEAN
eq_or_diff(~~$font->figify(-A=>'Paper'), $txt3, 'Clean TOIlet');


#4 Wrapped TOIlet
#If 3 fails, 4 probably will too
my $txt4 = <<'WRAP';
╻ ╻┏━╸╻  ╻  ┏━┓   ╻ ╻┏━┓┏━┓╻  ╺┳┓
┣━┫┣╸ ┃  ┃  ┃ ┃   ┃╻┃┃ ┃┣┳┛┃   ┃┃
╹ ╹┗━╸┗━╸┗━╸┗━┛   ┗┻┛┗━┛╹┗╸┗━╸╺┻┛
WRAP
my $out = ~~$font->figify(-A=>'Hello World',-w=>240);
eq_or_diff($out, $txt4, 'TOIlet wrapping');


#5&6 Compressed TOIlet
#If 3 fails, 5&6 probably will too
eval {$font = Text::FIGlet->new(-d=>'share', -f=>'emboss') };
exists($INC{'IO/Uncompress/Unzip.pm'}) ?
  ok(ref($font->{_fh}) eq 'IO::Uncompress::Unzip', 'IO::Uncompress:Unzip') :
  ok(                  -1,     "SKIPPING IO::Uncompress:Unzip"); #$@

my $txt6 = <<'TOIlet';
┃ ┃┏━┛┃  ┃  ┏━┃  ┃┃┃┏━┃┏━┃┃  ┏━ 
┏━┃┏━┛┃  ┃  ┃ ┃  ┃┃┃┃ ┃┏┏┛┃  ┃ ┃
┛ ┛━━┛━━┛━━┛━━┛  ━━┛━━┛┛ ┛━━┛━━ 
TOIlet
exists($INC{'IO/Uncompress/Unzip.pm'}) ?
  eq_or_diff(scalar $font->figify(-A=>'Hello World'), $txt6, 'TOIlet Zip') :
  ok(-1, "SKIPPING IO::Uncompress:Unzip");


#7 XXX Compressed FIGlet
