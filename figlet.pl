#!/usr/bin/perl
use strict;
use vars qw($VERSION $REVISION);
use Text::FIGlet;
$VERSION = '2.1';   #This is which figlet we are supposed to behave like
$REVISION = '1.06'; #This is build of the package/this component

my %opts;
$opts{$_} = undef for
  qw(A D E L R X c h help -help l r x);
$opts{$_} = "0 but true" for
  qw(I d f m w);
for(my $i=0; $i <= scalar @ARGV; $i++){
  shift && last if $ARGV[$i] eq '--';
  foreach my $key ( sort { length($b)-length($a) } keys %opts){
    if( $ARGV[$i] =~ /^-$key=?(.*)/ ){      
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


if( $opts{I} == 1 ){
    die($VERSION*1000, "\n");
}

my $font = Text::FIGlet->new(-D=>$opts{D}&!$opts{E},
			  -d=>$opts{d},
			  -m=>$opts{m},
			  -f=>$opts{f});

if( $opts{I} == 2 ){
    die("$font->{-d}\n");
}
if( $opts{I} == 3 ){
    die("$font->{-f}\n");
}

my %figify = (
	      -X=>($opts{L}&&'L')||($opts{R}&&'R'),
	      -m=>$opts{m},
	      -w=>$opts{w},
	      -x=>($opts{l}&&'l')||($opts{c}&&'c')||($opts{r}&&'r') );
if( $opts{A} ){
    @ARGV = map($_ = $_ eq '' ? $/ : $_, @ARGV);
    print $font->figify(-A=>join(' ', @ARGV), %figify);
    exit 0;
}
else{
    Text::FIGlet::croak("Usage: figlet.pl -help\n") if @ARGV;
    while(<STDIN>){
	print $font->figify(-A=>$_, %figify);
    }
}
__END__
=pod

=head1 NAME

figlet.pl - FIGlet in perl, akin to banner

=head1 SYNOPSIS

B<figlet.pl>
[ B<-A> ]
[ B<-D> ]
[ B<-E> ]
[ B<-L> ]
[ B<-R> ]
[ B<-X> ]
[ B<-c> ]
[ B<-d=>F<fontdirectory> ]
[ B<-f=>F<fontfile> ]
[ B<-help> ]
[ B<-l> ]
[ B<-r> ]
[ B<-w=>I<outputwidth> ]
[ B<-x> ]

=head1 DESCRIPTION

FIGlet  prints its input using large characters made up of
ordinary screen characters.  FIGlet  output  is  generally
reminiscent of the sort of "signatures" many people like
to put at the end of e-mail and UseNet  messages.   It  is
also  reminiscent  of  the output of some banner programs,
although it is oriented normally, not sideways.

FIGlet can print in a variety of fonts, both left-to-right
and  right-to-left,  with  adjacent  characters kerned and
"smushed" together in various ways.   FIGlet  fonts  are
stored  in  separate files, which can be identified by the
suffix ".flf".  Most FIGlet font files will be stored in
FIGlet's default font directory.

FIGlet  can  also  use "control files", which tell it to
map certain input characters to certain other  characters,
similar  to  the  Unix  tr  command.  Control files can be
identified by the suffix ".flc".   Most  FIGlet  control
files will be stored in FIGlet's default font directory.

=head1 OPTIONS

=over

=item B<-A>

All Words.  Once the  -  arguments  are  read,  all
words  remaining  on  the  command  line  are  used
instead of standard input to print letters.  Allows
shell  scripts  to  generate  large letters without
having to dummy up standard input files.

An empty character, obtained by two sequential  and
empty quotes, results in a line break.

To include text begining with - that might otherwise
appear to be an invalid argument, use the argument --

=item B<-D>
B<-E>

B<-D>  switches  to  the German (ISO 646-DE) character
set.  Turns `[', `\' and `]' into umlauted A, O and
U,  respectively.   `{',  `|' and `}' turn into the
respective lower case versions of these.  `~' turns
into  s-z.   B<-E>  turns  off  B<-D>  processing.  These
options are deprecated, which means  they  probably
will not appear in the next version of FIGlet.

=item B<-I>I<infocode>

These   options  print  various  information  about FIGlet, then exit.

1 Version (integer).

       This will print the version of your copy  of
       FIGlet  as a decimal integer.  The main version
       number is multiplied by 10000, the sub-
       version number is multiplied by 100, and the
       sub-sub-version number is multiplied  by  1.
       These  are added together, and the result is
       printed out.  For example, FIGlet 2.1.2 will
       print ``20102''.  If there is ever a version
       2.1.3, it will print ``20103''.   Similarly,
       version  3.7.2 would print ``30702''.  These
       numbers are guaranteed to be ascending, with
       later  versions having higher numbers.

2 Default font directory.

       This  will print the default font directory.
       It is affected by the -d option.

3 Font.

       This will print the name of the font  FIGlet
       would use.  It is affected by the B<-f> option.
       This is not a filename; the ``.flf''  suffix
       is not printed.

=item B<-L>
B<-R>
B<-X>

These  options  control whether FIGlet prints
left-to-right or  right-to-left. B<-L> selects
left-to-right printing. B<-R> selects right-to-left printing.
B<-X> (default) makes FIGlet use whichever is specified
in the font file.

=item B<-c>
B<-l>
B<-r>
B<-x>

These  options  handle  the justification of FIGlet
output.  B<-c> centers the  output  horizontally.   B<-l>
makes  the  output  flush-left.  B<-r> makes it flush-
right.  B<-x> (default) sets the justification according
to whether left-to-right or right-to-left text
is selected.  Left-to-right  text  will  be  flush-
left, while right-to-left text will be flush-right.
(Left-to-rigt versus right-to-left  text  is  controlled by B<-L>,
B<-R> and B<-X>.)

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

=item B<-m>I<smushmode>

Specifies how FIGlet should ``smush'' and kern consecutive
characters together.  On the command line,
B<-m0> can be useful, as it tells FIGlet to kern characters
without smushing them together.   Otherwise,
this option is rarely needed, as a FIGlet font file
specifies the best smushmode to use with the  font.
B<-m>  is,  therefore,  most  useful to font designers
testing the various smushmodes  with  their  font.
smushmode can be -2 through 63.

S<-2>
       Get mode from font file (default).

       Every  FIGlet  font  file specifies the best
       smushmode to use with the font.   This  will
       be  one  of  the  smushmodes (-1 through 63)
       described in the following paragraphs.
S<-1>
       No smushing or kerning.

       Characters are simply concatenated together.

S<-0>
       Fixed width.

       This will pad each character in the font such that they are all
       a consistent width. The padding is done such that the character
       is centered in it's "cell", and any odd padding is the trailing edge.

S<0>
       Kern only.

       Characters  are  pushed  together until they touch.

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

=head1 EXAMPLES

C<figlet.pl -A Hello "" World>

C<figlet.pl -m=-0 -demo>

=head1 ENVIRONMENT

figlet.pl will make use of these environment variables if present

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
