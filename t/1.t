use Test::Simple tests => 1;
use Test::Differences;
use Text::FIGlet;

$text = do{ local $/; <DATA> };
$/ = "\012";

my $test = Text::FIGlet->new(-d=>'share')->figify(-A=>"Hello World", -m=>-1);
chomp($test, $text);
eq_or_diff $test, $text, "Basic text";
__DATA__
 _   _        _  _         __        __              _      _ 
| | | |  ___ | || |  ___   \ \      / /  ___   _ __ | |  __| |
| |_| | / _ \| || | / _ \   \ \ /\ / /  / _ \ | '__|| | / _` |
|  _  ||  __/| || || (_) |   \ V  V /  | (_) || |   | || (_| |
|_| |_| \___||_||_| \___/     \_/\_/    \___/ |_|   |_| \__,_|
                                                              
