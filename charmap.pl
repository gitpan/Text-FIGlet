#!/usr/bin/perl
use strict;
use vars qw($VERSION $REVISION);
use Text::FIGlet;
$VERSION = '2.1';   #This is which figlet we are supposed to behave like
$REVISION = '1.06'; #This is build of the package/this component

my %opts;
$opts{$_} = undef for
  qw(h help -help);
$opts{$_} = "0 but true" for
  qw(d f w);
for (my $i=0; $i <= scalar @ARGV; $i++) {
  shift && last if $ARGV[$i] eq '--';
  foreach my $key ( sort { length($b)-length($a) } keys %opts) {
    if ( $ARGV[$i] =~ /^-$key=?(.*)/ ) {      
      shift; $i--;
      $opts{$key} = defined($1) && $1 ne '' ?
	$1 : defined($opts{$key}) ? do{$i--; shift} : 1;
      last;
    }
  }
}
$_ eq '0 but true' && ($_ = undef) for values %opts;
if( $opts{help}||$opts{h}||$opts{-help} ){
  eval "use Pod::Text;";
  die("Unable to print man page: $@\n") if $@;
  pod2text(__FILE__);
  exit 0;
}
Text::FIGlet::croak("Usage: charmap.pl -help\n") if @ARGV;


my $font = Text::FIGlet->new('_maxLen'=>8,
			     -d=>$opts{d},
			     -m=>'-0',
			     -f=>$opts{f});
my %figify = (
	      -m=>'-0',
	      -w=>$opts{w}),

my $n = int($opts{w}||80 / $font->{_maxLen});

#ASCII
{
  print "ASCII: [-\b-E\bE]\n\n";
  for(my$i=33; $i <= 127; $i++){
    printf "%s =%4i %s", chr($i), $i, ' 'x($font->{_maxLen}-8);
    print "\n", $font->figify(-A=>join('', map(chr($_), $i-$n+1..$i)),%figify),
      "\n" if ($i-32)%$n == 0;
  }
  if( my $r = 94 % $n ){
    print "\n", $font->figify(-A=>join('', map(chr($_), 127-$r..127)),%figify),
      "\n";
  }
}
  
my @buffer;
#German ... have to re-read :-(
{
  $font = Text::FIGlet->new('_maxLen'=>8,
			    -D=>1,
			    -d=>$opts{d},
			    -m=>'-0',
			    -f=>$opts{f});

  $n = int($opts{w}||80 / $font->{_maxLen});

  print "German: [-\b-D\bD]\n\n";
  @buffer = qw(91 92 93 123 124 125 126);
  
  unshift @buffer, '';
  for(my$i=1; $i < scalar @buffer; $i++){
    printf "%s =%4i %s", chr($buffer[$i]), $buffer[$i], ' 'x($font->{_maxLen}-8);
    if( $i%$n == 0 ){
      print "\n", $font->figify(-A=>join('', map(chr($_), @buffer[$i-$n+1..$i])),%figify), "\n";
      splice(@buffer,1,$n);
      $i-=$n;
    }
  }
  if( scalar @buffer -1 ){
    print "\n", $font->figify(-A=>join('', map(chr($_), @buffer)),%figify),
      "\n" ;
  }
}
exit unless scalar @{$font->{_font}} > 128;

#Extended chars...
{
  print "Extended Characters\n\n";
  @buffer = ();
  for(my$i=128; $i <= scalar @{$font->{_font}}; $i++){
    next unless $font->{_font}->[$i] && scalar @{$font->{_font}->[$i]} > 1;
    push @buffer, $i;
    printf "%s =%4i %s", chr($i), $i, ' 'x($font->{_maxLen}-8);
    if( scalar @buffer == $n ){
      print "\n", $font->figify(-A=>join('', map(chr($_), @buffer)),%figify),
	"\n" ;
      @buffer = ();
    }
  }
  if( scalar @buffer ){
    print "\n", $font->figify(-A=>join('', map(chr($_), @buffer)),%figify),
      "\n" ;
  }
}
__END__
=pod

=head1 NAME

charmap.pl - display a FIGfont  with associated codes

=head1 SYNOPSIS

B<figlet.pl>
[ B<-d=>F<fontdirectory> ]
[ B<-f=>F<fontfile> ]
[ B<-help> ]
[ B<-w=>I<outputwidth> ]

=head1 DESCRIPTION

Charmap doesn't tell you anything you can't find out
by viewing a font in your favorite pager. However,
it does have a few advantages.

=over

=item * You don't have to ignore hardspaces (though you could do this with tr)

=item * It displays more than one FIGchar per FIGline

=back

=head1 OPTIONS

=over

=item B<-d>=F<fontdirectory>

Change the default font  directory.   FIGlet  looks
for  fonts  first in the default directory and then
in the current directory.  If the B<-d> option is  not
specified, FIGlet uses the directory that was specified
when it was  compiled.   To  find  out  which
directory this is, use the B<-I2> option.

=item B<-f>=F<fontfile>

Select the font.  The .flf suffix may be  left  off
of  fontfile,  in  which  case FIGlet automatically
appends it.  FIGlet looks for the file first in the
default  font  directory  and  then  in the current
directory, or, if fontfile  was  given  as  a  full
pathname, in the given directory.  If the B<-f> option
is not specified, FIGlet uses  the  font  that  was
specified  when it was compiled.  To find out which
font this is, use the B<-I3> option.

=item B<-w>=I<outputwidth>

These  options  control  the  outputwidth,  or  the
screen width FIGlet  assumes  when  formatting  its
output.   FIGlet  uses the outputwidth to determine
when to break lines and how to center  the  output.
Normally,  FIGlet assumes 80 columns so that people
with wide terminals won't annoy the people they  e-mail
FIGlet output to. B<-w> sets the  outputwidth 
to  the  given integer.   An  outputwidth  of 1 is a
special value that tells FIGlet to print each non-
space  character, in its entirety, on a separate line,
no matter how wide it is. Another special outputwidth
is -1, it means to not warp.

=back

=head1 ENVIRONMENT

charmap.pl will make use of these environment variables if present

=over

=item FIGFONT

The default font to load.
It should reside in the directory specified by FIGLIB.

=item FIGLIB

The default location of fonts.

=back

=head1 FILES

FIGlet home page

 http://st-www.cs.uiuc.edu/users/chai/figlet.html
 http://mov.to/figlet/

FIGlet font files, these can be found at

 http://www.internexus.net/pub/figlet/
 ftp://wuarchive.wustl.edu/graphics/graphics/misc/figlet/
 ftp://ftp.plig.org/pub/figlet/

=head1 SEE ALSO

L<figlet>, L<Text::FIGlet>

=head1 AUTHOR

Jerrad Pierce <jpierce@cpan.org>|<webmaster@pthbb.org>

=cut
