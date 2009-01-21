BEGIN{ exit -1 if $] < 5.006; eval "use Test::Simple tests => 4; use Test::Differences"; }
use Text::FIGlet;


#0 implicit -d test
my $font = Text::FIGlet->new(-d=>'t', -f=>'2', -U=>1);


#1
#XX Skip if $] < 5.006;
my $txt1=<<'UNICODE';
 _\_/_ _ \\//
|__  /| | \/ 
  / / | |    
 / /_ | |___ 
/____||_____|
             
UNICODE
eq_or_diff scalar $font->figify(-A=>"\x{17d}\x{13d}", -U=>1), $txt1, "Unicode";


#2
print "#Neg. char mapping currently unvavail. in pre-5.6 perl\n" if $] < 5.006;
$ctrl = Text::FIGlet->new(-d=>'t', -C=>'2.flc') ||
  warn("#Failed to load negative character mapping control file: $!\n");
my $txt2 = <<'-CHAR';
   
   
 o 
/|/
/| 
\| 
-CHAR
eq_or_diff scalar $font->figify(-U=>1, -A=>$ctrl->tr('~')), $txt2, "-CHAR";


#3
eval {$font = Text::FIGlet->new(-d=>'share', -f=>'emboss') };
$@ ? ok(-1, "SKIPPING Zlib: $@") :
   ok(ref($font->{_fh}) eq 'IO::Uncompress::Unzip', 'Zlib');


#4
my $txt4 = <<'TOIlet';
┃ ┃┏━┛┃  ┃  ┏━┃
┏━┃┏━┛┃  ┃  ┃ ┃
┛ ┛━━┛━━┛━━┛━━┛
┃┃┃┏━┃┏━┃┃  ┏━ 
┃┃┃┃ ┃┏┏┛┃  ┃ ┃
━━┛━━┛┛ ┛━━┛━━ 
TOIlet
$@ ? ok(-1, "SKIPPING TOIlet w/o Zlib") :
   eq_or_diff(scalar $font->figify(-A=>'Hello World'), $txt4, 'TOIlet');