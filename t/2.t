use Test::Simple tests => 1;
use Test::Differences;
use Text::FIGlet;

$text = do{ local $/; <DATA> };
$/ = "\012";
my $test = Text::FIGlet->new(-d=>'share',
			     -D=>1)->figify(-A=>'~'.chr(164), -m=>-1);
chomp($test, $text);
eq_or_diff $test, $text, "German + High bit";
__DATA__
  ___ /\___/\
 / _ \\  _  /
| |/ /| (_) |
| |\ \/ ___ \
| ||_/\/   \/
|_|          
