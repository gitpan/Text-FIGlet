#!/usr/bin/perl -s
package Text::FIGlet;
$VERSION = '1.04';
use Carp qw(carp croak);
use File::Spec;
use File::Basename qw(basename);
use Text::Wrap;
use strict;

sub new{
    shift();
    my $self = {@_};

    $self->{-f} ||= $ENV{FIGFONT};
    $self->{-d} ||= $ENV{FIGLIB}  || '/usr/games/lib/figlet/';
    #translate dir seperator in FIGLIB
    _load_font($self);
    bless($self);
    return $self;
}

sub _load_font($) {
    my $self = shift();
    my(@header, $header, $font);
    local $_;

    $font = File::Spec->catfile($self->{-d}, basename($self->{-f}));
    if( $self->{-f} ){
	open(FLF, $font) || open(FLF, "$font.flf") || croak("$!: $font");
    }
    else{
	*FLF = *main::DATA;
	while( <FLF> ){
	    last if /__DATA__/;
	}
    }

    chomp($header = <FLF>);
    croak("Invalid figlet 2 font") unless $header =~ /^flf2/;

    #flf2ahardblank height up_ht maxlen smushmode cmt_count rtol
    @header = split(/\s+/, $header);
    $header[0] =~ s/^flf2.//;
    $header[0] = quotemeta($header[0]);
    $self->{_header} = \@header;

    #Discard comments
    for(my $i=0; $i<$header[5]; $i++){
        <FLF> || carp("Unexpected end of font file") && last;
    }

    #Get ASCII characters
    for(my $i=32; $i<127; $i++){
	_load_char($self, $i) || last;
    }

    #German characters?
    unless( eof(FLF) ){
	for(-255,-254,-253,-252,-251,-250,-249){
	    _load_char($self, $_) || last;
	}
	if( $self->{-D} ){
	    my %h = (91=>-255,92=>-254,93=>-253,123=>-252,124=>-251,125=>-250,126=>-249);
	    while( my($k, $v) = each(%h) ){
		$self->{_font}->{$k} = $self->{_font}->{$v};
	    }
	}
    }

    #Extended characters, read extra line to get code
    until( eof(FLF) ){
	$_ = <FLF> || carp("Unexpected end of font file") && last;
	/^(\w+)/;
	last unless $1;
	_load_char($self, eval $1) || last;
    }

    if( $self->{-m} eq '-0' ){
	my $len;
	foreach my $ord ( keys %{$self->{_font}} ){
	    for(my $i=1; $i<=$self->{_header}->[1]; $i++ ){
		$len = length($self->{_font}->{$ord}->[$i]);
		if( $self->{_maxlen} > $len ){
		    $len = $self->{_maxlen} - $len;
		    $self->{_font}->{$ord}->[$i] =
			" " x int($len/2) .
			    $self->{_font}->{$ord}->[$i] .
				" " x ($len-int($len/2));
		}
	    }
	    $self->{_font}->{$ord}->[0] = $self->{_maxlen};
	}
    }
}

sub _load_char($$){
    my($self, $i) = @_;
    my $length;

    for(my $j=0; $j<$self->{_header}->[1]; $j++){
	local $_ = <FLF> || carp("Unexpected end of font file") && return 0;
	$self->{_font}->{$i} .= $_;
	$length = $length > length($_) ? $length : length($_);
	if( $self->{-m} eq '-0' ){
	    $length -= (s/(^\s+)|(\s+$)//g);
	    $self->{_maxlen} = $length > $self->{_maxlen} ?
		$length : $self->{_maxlen};
	}
    }
    $self->{_font}->{$i} =~ /(.){2}$/;
    $self->{_font}->{$i} =~ s/$1|\015//g;
    $self->{_font}->{$i} = [$length-3, split($/, $self->{_font}->{$i})];
    return 1;
}


sub figify{
    my $self = shift();
    my %opts = @_;
    my($buffer, @text);
    local $_;

    $opts{-w} ||= 80;

    #Do text formatting here...
    $opts{-A} =~ tr/\t/ /;
    $opts{-A} =~  s%$/%\n%;
    if( $opts{-m} eq '-0' ){
	$Text::Wrap::columns = int($opts{-w} / $self->{_maxlen});
	$opts{-A} = Text::Wrap::wrap('', '', $opts{-A}), "\n";
    }
    else{
	$Text::Wrap::columns = $opts{-w}+1;
	@text = split(//, $opts{-A});
	$opts{-A} = '';
	foreach( @text ){
	    $opts{-A} .= $_ . "\0" x ($self->{_font}->{ord($_)}->[0]-1);
	}
        $opts{-A} = Text::Wrap::wrap('', '', $opts{-A}), "\n";
	$opts{-A} =~ tr/\0//d;
    }
    @text = split("\n", $opts{-A});

    foreach( @text ){
	s/^\s*//o;
	my @lchars = map(ord($_), split('', $_));
	for(my $i=1; $i<=$self->{_header}->[1]; $i++){
	    foreach my $lchar (@lchars){
		if( exists($self->{_font}->{$lchar}) ){
		    $buffer .= $self->{_font}->{$lchar}->[$i];
		}
		else{
		    $buffer .= $self->{_font}->{32}->[$i];
		}
	    }
	    $buffer .= $/;
	}
    }
    $buffer =~ s/$self->{_header}->[0]/ /g;
    return $buffer;
}
package main;
no strict;
use vars qw($A $D $F $I1 $I2 $I3 $d $demo $f $help $m $w);
$VERSION = '2.02';
if( $help ){
    eval "use Pod::Text;";
    die("Unable to print man page: $@\n") if $@;
    pod2text(__FILE__);
    exit 0;
}
if($I1){
    die($VERSION*1000, "\n");
}

$font = Text::FIGlet->new(-D=>$D, -F=>$F, -d=>$d, -m=>$m, -f=>$f);

if($I2){
    die("$font->{-d}\n");
}
if($I3){
    die("$font->{-f}\n");
}

if( $demo ){
    print $font->figify(-A=>join('', map(chr($_), 33..127)), -w=>$w);
    exit 0;
}
if( $A ){
    @ARGV = map($_ = $_ eq '' ? $/ : $_, @ARGV);
    print $font->figify(-A=>join(' ', @ARGV), -m=>$m, -w=>$w);
}
else{
    Text::FIGlet::croak("Usage: minifig.pl -help") if @ARGV;
    while(<STDIN>){
	print $font->figify(-A=>$_, -m=>$m, -w=>$w);
    }
}
__END__
=pod

=head1 NAME

minifig.pl - FIGlet in perl, akin to banner

=head1 SYNOPSIS

B<minifig.pl>
[ B<-A> ]
[ B<-D> ]
[ B<-d=>F<fontdirectory> ]
[ B<-demo> ]
[ B<-f=>F<fontfile> ]
[ B<-help> ]
[ B<-m=>I<smushmode> ]
[ B<-w=>I<outputwidth> ]

=head1 DESCRIPTION

B<minifig.pl> is a self contained version of B<figlet.pl>
that requires nothing more than a standard Perl distribution.
This makes it even more portable and ideal for distribution
than B<figlet.pl>. See F<minifig.HOWTO> for more information.

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

Switches  to  the German (ISO 646-DE) character
set.  Turns `[', `\' and `]' into umlauted A, O and
U,  respectively.   `{',  `|' and `}' turn into the
respective lower case versions of these.  `~' turns
into  s-z. This option is deprecated, which means it
may not appear in upcoming versions of FIGlet.

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

=item B<-m>I<smushmode>

Specifies how FIGlet should ``smush'' and kern consecutive
characters together.  On the command line,
B<-m0> can be useful, as it tells FIGlet to kern characters
without smushing them together.   Otherwise,
this option is rarely needed, as a FIGlet font file
specifies the best smushmode to use with the  font.
B<-m>  is,  therefore,  most  useful to font designers
testing the various  

S<-1> Is currently the default, B<figlet>'s default is S<-2>

S<-1>
       No smushing or kerning.
       Characters are simply concatenated together.

S<-0>
       This will pad each character in the font such that they are all
       a consistent width. The padding is done such that the character
       is centered in it's "cell", and any odd padding is the trailing edge.

       NOTE: This should probably be considered experimental

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

C<minifig.pl -A Hello "" World>

C<minifig.pl -m=-0 -demo>

=head1 ENVIRONMENT

minifig.pl will make use of these environment variables if present

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

L<figlet>, L<Text::FIGlet>, L<figlet.pl>

=head1 AUTHOR

Jerrad Pierce <jpierce@cpan.org>/<webmaster@pthbb.rg>

=cut
__DATA__
flf2a$ 4 3 10 0 10 0 1920 96
Mini by Glenn Chappell 4/93
Includes ISO Latin-1
figlet release 2.1 -- 12 Aug 1994
Permission is hereby given to modify this font, as long as the
modifier's name is placed on a comment line.

Modified by Paul Burton <solution@earthlink.net> 12/96 to include new parameter
supported by FIGlet and FIGWin.  May also be slightly modified for better use
of new full-width/kern/smush alternatives, but default output is NOT changed.

$$@
$$@
$$@
$$@@
   @
 |$@
 o$@
   @@
    @
 ||$@
    @
    @@
       @
 -|-|-$@
 -|-|-$@
       @@
   _$@
 (|$ @
 _|)$@
     @@
    @
 O/$@
 /O$@
    @@
     @
 ()$ @
 (_X$@
     @@
   @
 /$@
   @
   @@
    @
  /$@
 |$ @
  \$@@
    @
 \$ @
  |$@
 /$ @@
     @
 \|/$@
 /|\$@
     @@
     @
 _|_$@
  |$ @
     @@
   @
   @
 o$@
 /$@@
    @
 __$@
    @
    @@
   @
   @
 o$@
   @@
    @
  /$@
 /$ @
    @@
  _$ @
 / \$@
 \_/$@
     @@
    @
 /|$@
  |$@
    @@
 _$ @
  )$@
 /_$@
    @@
 _$ @
 _)$@
 _)$@
    @@
      @
 |_|_$@
   |$ @
      @@
  _$ @
 |_$ @
  _)$@
     @@
  _$ @
 |_$ @
 |_)$@
     @@
 __$@
  /$@
 /$ @
    @@
  _$ @
 (_)$@
 (_)$@
     @@
  _$ @
 (_|$@
   |$@
     @@
   @
 o$@
 o$@
   @@
   @
 o$@
 o$@
 /$@@
   @
 /$@
 \$@
   @@
    @
 --$@
 --$@
    @@
   @
 \$@
 /$@
   @@
 _$ @
  )$@
 o$ @
    @@
   __$ @
  /  \$@
 | (|/$@
  \__$ @@
      @
  /\$ @
 /--\$@
      @@
  _$ @
 |_)$@
 |_)$@
     @@
  _$@
 /$ @
 \_$@
    @@
  _$ @
 | \$@
 |_/$@
     @@
  _$@
 |_$@
 |_$@
    @@
  _$@
 |_$@
 |$ @
    @@
  __$@
 /__$@
 \_|$@
     @@
     @
 |_|$@
 | |$@
     @@
 ___$@
  |$ @
 _|_$@
     @@
     @
   |$@
 \_|$@
     @@
    @
 |/$@
 |\$@
    @@
    @
 |$ @
 |_$@
    @@
      @
 |\/|$@
 |  |$@
      @@
      @
 |\ |$@
 | \|$@
      @@
  _$ @
 / \$@
 \_/$@
     @@
  _$ @
 |_)$@
 |$  @
     @@
  _$ @
 / \$@
 \_X$@
     @@
  _$ @
 |_)$@
 | \$@
     @@
  __$@
 (_$ @
 __)$@
     @@
 ___$@
  |$ @
  |$ @
     @@
     @
 | |$@
 |_|$@
     @@
      @
 \  /$@
  \/$ @
      @@
        @
 \    /$@
  \/\/$ @
        @@
    @
 \/$@
 /\$@
    @@
     @
 \_/$@
  |$ @
     @@
 __$@
  /$@
 /_$@
    @@
  _$@
 |$ @
 |_$@
    @@
    @
 \$ @
  \$@
    @@
 _$ @
  |$@
 _|$@
    @@
 /\$@
    @
    @
    @@
    @
    @
    @
 __$@@
   @
 \$@
   @
   @@
     @
  _.$@
 (_|$@
     @@
     @
 |_$ @
 |_)$@
     @@
    @
  _$@
 (_$@
    @@
     @
  _|$@
 (_|$@
     @@
     @
  _$ @
 (/_$@
     @@
   _$@
 _|_$@
  |$ @
     @@
     @
  _$ @
 (_|$@
  _|$@@
     @
 |_$ @
 | |$@
     @@
   @
 o$@
 |$@
   @@
    @
  o$@
  |$@
 _|$@@
    @
 |$ @
 |<$@
    @@
   @
 |$@
 |$@
   @@
       @
 ._ _$ @
 | | |$@
       @@
     @
 ._$ @
 | |$@
     @@
     @
  _$ @
 (_)$@
     @@
     @
 ._$ @
 |_)$@
 |$  @@
     @
  _.$@
 (_|$@
   |$@@
    @
 ._$@
 |$ @
    @@
    @
  _$@
 _>$@
    @@
     @
 _|_$@
  |_$@
     @@
     @
     @
 |_|$@
     @@
    @
    @
 \/$@
    @@
      @
      @
 \/\/$@
      @@
    @
    @
 ><$@
    @@
    @
    @
 \/$@
 /$ @@
    @
 _$ @
 /_$@
    @@
  ,-$@
 _|$ @
  |$ @
  `-$@@
 |$@
 |$@
 |$@
 |$@@
 -.$ @
  |_$@
  |$ @
 -'$ @@
 /\/$@
     @
     @
     @@
 o  o$@
  /\$ @
 /--\$@
      @@
 o_o$@
 / \$@
 \_/$@
     @@
 o o$@
 | |$@
 |_|$@
     @@
 o o$@
  _.$@
 (_|$@
     @@
 o o$@
  _$ @
 (_)$@
     @@
 o o$@
     @
 |_|$@
     @@
  _$ @
 | )$@
 | )$@
 |$  @@
160  NO-BREAK SPACE
 $$@
 $$@
 $$@
 $$@@
161  INVERTED EXCLAMATION MARK
   @
 o$@
 |$@
   @@
162  CENT SIGN
     @
  |_$@
 (__$@
  |$ @@
163  POUND SIGN
    _$  @
  _/_`$ @
   |___$@
        @@
164  CURRENCY SIGN
     @
 `o'$@
 ' `$@
     @@
165  YEN SIGN
       @
 _\_/_$@
 --|--$@
       @@
166  BROKEN BAR
 |$@
 |$@
 |$@
 |$@@
167  SECTION SIGN
  _$@
 ($ @
 ()$@
 _)$@@
168  DIAERESIS
 o o$@
     @
     @
     @@
169  COPYRIGHT SIGN
  _$ @
 |C|$@
 `-'$@
     @@
170  FEMININE ORDINAL INDICATOR
  _.$@
 (_|$@
 ---$@
     @@
171  LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
    @
 //$@
 \\$@
    @@
172  NOT SIGN
     @
 __$ @
   |$@
     @@
173  SOFT HYPHEN
   @
 _$@
   @
   @@
174  REGISTERED SIGN
  _$ @
 |R|$@
 `-'$@
     @@
175  MACRON
 __$@
    @
    @
    @@
176  DEGREE SIGN
 O$@
   @
   @
   @@
177  PLUS-MINUS SIGN
     @
 _|_$@
 _|_$@
     @@
178  SUPERSCRIPT TWO
 2$@
   @
   @
   @@
179  SUPERSCRIPT THREE
 3$@
   @
   @
   @@
180  ACUTE ACCENT
 /$@
   @
   @
   @@
181  MICRO SIGN
     @
     @
 |_|$@
 |$  @@
182  PILCROW SIGN
  __$ @
 (| |$@
  | |$@
      @@
183  MIDDLE DOT
   @
 o$@
   @
   @@
184  CEDILLA
   @
   @
   @
 S$@@
185  SUPERSCRIPT ONE
 1$@
   @
   @
   @@
186  MASCULINE ORDINAL INDICATOR
  _$ @
 (_)$@
 ---$@
     @@
187  RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
    @
 \\$@
 //$@
    @@
188  VULGAR FRACTION ONE QUARTER
    @
 1/$@
 /4$@
    @@
189  VULGAR FRACTION ONE HALF
    @
 1/$@
 /2$@
    @@
190  VULGAR FRACTION THREE QUARTERS
    @
 3/$@
 /4$@
    @@
191  INVERTED QUESTION MARK
    @
  o$@
 (_$@
    @@
192  LATIN CAPITAL LETTER A WITH GRAVE
   \$ @
  /\$ @
 /--\$@
      @@
193  LATIN CAPITAL LETTER A WITH ACUTE
  /$  @
  /\$ @
 /--\$@
      @@
194  LATIN CAPITAL LETTER A WITH CIRCUMFLEX
  /\$ @
  /\$ @
 /--\$@
      @@
195  LATIN CAPITAL LETTER A WITH TILDE
  /\/$@
  /\$ @
 /--\$@
      @@
196  LATIN CAPITAL LETTER A WITH DIAERESIS
 o  o$@
  /\$ @
 /--\$@
      @@
197  LATIN CAPITAL LETTER A WITH RING ABOVE
   O$  @
  / \$ @
 /---\$@
       @@
198  LATIN CAPITAL LETTER AE
    _$@
  /|_$@
 /-|_$@
      @@
199  LATIN CAPITAL LETTER C WITH CEDILLA
  _$@
 /$ @
 \_$@
  S$@@
200  LATIN CAPITAL LETTER E WITH GRAVE
 \_$@
 |_$@
 |_$@
    @@
201  LATIN CAPITAL LETTER E WITH ACUTE
  _/$@
 |_$ @
 |_$ @
     @@
202  LATIN CAPITAL LETTER E WITH CIRCUMFLEX
  /\$@
 |_$ @
 |_$ @
     @@
203  LATIN CAPITAL LETTER E WITH DIAERESIS
 o_o$@
 |_$ @
 |_$ @
     @@
204  LATIN CAPITAL LETTER I WITH GRAVE
 \__$@
  |$ @
 _|_$@
     @@
205  LATIN CAPITAL LETTER I WITH ACUTE
 __/$@
  |$ @
 _|_$@
     @@
206  LATIN CAPITAL LETTER I WITH CIRCUMFLEX
  /\$@
 ___$@
 _|_$@
     @@
207  LATIN CAPITAL LETTER I WITH DIAERESIS
 o_o$@
  |$ @
 _|_$@
     @@
208  LATIN CAPITAL LETTER ETH
   _$ @
 _|_\$@
  |_/$@
      @@
209  LATIN CAPITAL LETTER N WITH TILDE
  /\/$@
 |\ |$@
 | \|$@
      @@
210  LATIN CAPITAL LETTER O WITH GRAVE
  \$ @
 / \$@
 \_/$@
     @@
211  LATIN CAPITAL LETTER O WITH ACUTE
  /$ @
 / \$@
 \_/$@
     @@
212  LATIN CAPITAL LETTER O WITH CIRCUMFLEX
  /\$@
 / \$@
 \_/$@
     @@
213  LATIN CAPITAL LETTER O WITH TILDE
 /\/$@
 / \$@
 \_/$@
     @@
214  LATIN CAPITAL LETTER O WITH DIAERESIS
 o_o$@
 / \$@
 \_/$@
     @@
215  MULTIPLICATION SIGN
   @
   @
 X$@
   @@
216  LATIN CAPITAL LETTER O WITH STROKE
  __$ @
 / /\$@
 \/_/$@
      @@
217  LATIN CAPITAL LETTER U WITH GRAVE
  \$ @
 | |$@
 |_|$@
     @@
218  LATIN CAPITAL LETTER U WITH ACUTE
  /$ @
 | |$@
 |_|$@
     @@
219  LATIN CAPITAL LETTER U WITH CIRCUMFLEX
  /\$@
 | |$@
 |_|$@
     @@
220  LATIN CAPITAL LETTER U WITH DIAERESIS
 o o$@
 | |$@
 |_|$@
     @@
221  LATIN CAPITAL LETTER Y WITH ACUTE
  /$ @
 \_/$@
  |$ @
     @@
222  LATIN CAPITAL LETTER THORN
 |_$ @
 |_)$@
 |$  @
     @@
223  LATIN SMALL LETTER SHARP S
  _$ @
 | )$@
 | )$@
 |$  @@
224  LATIN SMALL LETTER A WITH GRAVE
  \$ @
  _.$@
 (_|$@
     @@
225  LATIN SMALL LETTER A WITH ACUTE
  /$ @
  _.$@
 (_|$@
     @@
226  LATIN SMALL LETTER A WITH CIRCUMFLEX
  /\$@
  _.$@
 (_|$@
     @@
227  LATIN SMALL LETTER A WITH TILDE
 /\/$@
  _.$@
 (_|$@
     @@
228  LATIN SMALL LETTER A WITH DIAERESIS
 o o$@
  _.$@
 (_|$@
     @@
229  LATIN SMALL LETTER A WITH RING ABOVE
  O$ @
  _.$@
 (_|$@
     @@
230  LATIN SMALL LETTER AE
       @
  ___$ @
 (_|/_$@
       @@
231  LATIN SMALL LETTER C WITH CEDILLA
    @
  _$@
 (_$@
  S$@@
232  LATIN SMALL LETTER E WITH GRAVE
  \$ @
  _$ @
 (/_$@
     @@
233  LATIN SMALL LETTER E WITH ACUTE
  /$ @
  _$ @
 (/_$@
     @@
234  LATIN SMALL LETTER E WITH CIRCUMFLEX
  /\$@
  _$ @
 (/_$@
     @@
235  LATIN SMALL LETTER E WITH DIAERESIS
 o o$@
  _$ @
 (/_$@
     @@
236  LATIN SMALL LETTER I WITH GRAVE
 \$@
   @
 |$@
   @@
237  LATIN SMALL LETTER I WITH ACUTE
 /$@
   @
 |$@
   @@
238  LATIN SMALL LETTER I WITH CIRCUMFLEX
 /\$@
    @
 |$ @
    @@
239  LATIN SMALL LETTER I WITH DIAERESIS
 o o$@
     @
  |$ @
     @@
240  LATIN SMALL LETTER ETH
 X$  @
  \$ @
 (_|$@
     @@
241  LATIN SMALL LETTER N WITH TILDE
 /\/$@
 ._$ @
 | |$@
     @@
242  LATIN SMALL LETTER O WITH GRAVE
  \$ @
  _$ @
 (_)$@
     @@
243  LATIN SMALL LETTER O WITH ACUTE
  /$ @
  _$ @
 (_)$@
     @@
244  LATIN SMALL LETTER O WITH CIRCUMFLEX
  /\$@
  _$ @
 (_)$@
     @@
245  LATIN SMALL LETTER O WITH TILDE
 /\/$@
  _$ @
 (_)$@
     @@
246  LATIN SMALL LETTER O WITH DIAERESIS
 o o$@
  _$ @
 (_)$@
     @@
247  DIVISION SIGN
  o$ @
 ---$@
  o$ @
     @@
248  LATIN SMALL LETTER O WITH STROKE
     @
  _$ @
 (/)$@
     @@
249  LATIN SMALL LETTER U WITH GRAVE
  \$ @
     @
 |_|$@
     @@
250  LATIN SMALL LETTER U WITH ACUTE
  /$ @
     @
 |_|$@
     @@
251  LATIN SMALL LETTER U WITH CIRCUMFLEX
  /\$@
     @
 |_|$@
     @@
252  LATIN SMALL LETTER U WITH DIAERESIS
 o o$@
     @
 |_|$@
     @@
253  LATIN SMALL LETTER Y WITH ACUTE
  /$@
    @
 \/$@
 /$ @@
254  LATIN SMALL LETTER THORN
     @
 |_$ @
 |_)$@
 |$  @@
255  LATIN SMALL LETTER Y WITH DIAERESIS
 oo$@
    @
 \/$@
 /$ @@
