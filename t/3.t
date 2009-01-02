use Test::Simple tests => 1;
use Test::Differences;
use Text::FIGlet;

$text = do{ local $/; <DATA> };
$/ = "\012";
my $test = Text::FIGlet->new(-d=>'share',
			    )->figify(-A=>'~'.chr(0x17d).chr(0x13d),
					    -m=>-1, -U=>1);
chomp($test, $text);
eq_or_diff $test, $text, "Unicode";
__DATA__
 /\/| _\_/_ _ \\//
|/\/ |__  /| | \/ 
       / / | |    
      / /_ | |___ 
     /____||_____|
                  
