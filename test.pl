# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use Text::FIGlet;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):
open(IN, "test.txt") || warn("No sample output to compare against\n");
while(<IN>){
    chomp();
    $txt .= $_ . $/;
}
#print $txt;
#print "="x80;
#print Text::FIGlet->new(-d=>'.')->figify(-A=>"Hello World");
print "not " unless $txt eq Text::FIGlet->new(-d=>'.')->figify(-A=>"Hello World");
print "ok 2\n";
