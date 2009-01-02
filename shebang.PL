#!perl -pi~
BEGIN{
  @ARGV = glob("bin/*.pl");
}
s/#!.*perl/#!$^X/;
