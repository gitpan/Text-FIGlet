#!/usr/bin/perl -s
use vars qw($A $D $F $I1 $I2 $I3 $d $f $help $w);
use Text::FIGlet;
$VERSION = '2.0';
if( $help ){
    eval "use Pod::Text;";
    die("Unable to print man page: $@\n") if $@;
    pod2text(__FILE__);
    exit 0;
}
if($I1){
    die($VERSION*1000, "\n");
}

$font = Text::FIGlet->new(-D=>$D, -F=>$F, -d=>$d, -f=>$f);

if($I2){
    die("$font->{-d}\n");
}
if($I3){
    die("$font->{-f}\n");
}

if( $A ){
    @ARGV = map($_ = $_ eq '' ? $/ : $_, @ARGV);
    print $font->figify(-A=>join(' ', @ARGV), -w=>$w), "\n";
}
else{
    #complain if @ARGV;
    while(<STDIN>){
	print $font->figify(-A=>$_, -w=>$w), "\n";
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
[ B<-F> ]
[ B<-d=>F<fontdirectory> ]
[ B<-demo> ]
[ B<-f=>F<fontfile> ]
[ B<-w=>I<outputwidth>

=head1 DESCRIPTION

=over

=item B<-A>

All Words.  Once the  -  arguments  are  read,  all
words  remaining  on  the  command  line  are  used
instead of standard input to print letters.  Allows
shell  scripts  to  generate  large letters without
having to dummy up standard input files.

An empty character, obtained by two sequential  and
empty quotes, results in a line break.

=item B<-D>

Switches  to  the German (ISO 646-DE) character
set.  Turns `[', `\' and `]' into umlauted A, O and
U,  respectively.   `{',  `|' and `}' turn into the
respective lower case versions of these.  `~' turns
into  s-z. This option is deprecated, which means it
may not appear in upcoming versions of FIGlet.

=item B<-F>

This will pad each character in the font such that they are all
a consistent width. The padding is done such that the character
is centered in it's "cell", and any odd padding is the trailing edge.

NOTE: This should probably be considered experimental

=item B<-I>I<infocode>

These   options  print  various  information  about FIGlet, then exit.

1 Version (integer).

       This will print the version of your copy  of
       FIGlet  as a decimal integer.  The main verÅ≠
       sion number is multiplied by 10000, the sub-
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

=item B<-d>=F<fontdirectory>

Change the default font  directory.   FIGlet  looks
for  fonts  first in the default directory and then
in the current directory.  If the <d> option is  not
specified, FIGlet uses the directory that was specÅ≠
ified when it was  compiled.   To  find  out  which
directory this is, use the B<I2> option.

=item B<-demo>

Outputs the ASCII codepage in the specified font.

=item B<-f>=F<fontfile>

Select the font.  The .flf suffix may be  left  off
of  fontfile,  in  which  case FIGlet automatically
appends it.  FIGlet looks for the file first in the
default  font  directory  and  then  in the current
directory, or, if fontfile  was  given  as  a  full
pathname, in the given directory.  If the B<-f> option
is not specified, FIGlet uses  the  font  that  was
specified  when it was compiled.  To find out which
font this is, use the B<I3> option.

=item B<-w>=I<outputwidth>

These  options  control  the  outputwidth,  or  the
screen width FIGlet  assumes  when  formatting  its
output.   FIGlet  uses the outputwidth to determine
when to break lines and how to center  the  output.
Normally,  FIGlet assumes 80 columns so that people
with wide terminals won't annoy the people they  e-mail
FIGlet output to. B<w> sets the  outputwidth 
to  the  given integer.   An  outputwidth  of 1 is a
special value that tells FIGlet to print each non-
space  character, in its entirety, on a separate line,
no matter how wide it is. Another special outputwidth
is -1, it means to not warp.

=back

=head1 EXAMPLES

C<figlet.pl -A Hello "" World>

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

FIGlet font files, these can be found at

 http://st-www.cs.uiuc.edu/users/chai/figlet.html
 http://www.internexus.net/pub/figlet/
 ftp://wuarchive.wustl.edu/graphics/graphics/misc/figlet/
 ftp://ftp.plig.org/pub/figlet/


=head1 SEE ALSO

L<figlet>, L<Text::FIGlet>

=head1 AUTHOR

Jerrad Pierce <jpierce@cpan.org>/<webmaster@pthbb.rg>

=cut
