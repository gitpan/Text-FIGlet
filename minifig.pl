#!/usr/bin/perl -s
package Text::FIGlet;
$VERSION = '1.05';
use 5;
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

    $font = File::Spec->catfile(
			      File::Spec->file_name_is_absolute($self->{-f}) ?
				'' : $self->{-d},
			      File::Spec->file_name_is_absolute($self->{-f}) ?
				$self->{-f} : basename($self->{-f}) );
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

    unless( defined($self->{-m}) || $self->{-m} eq '-2' ){
	$self->{-m} = $header[4];
    }

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
	foreach my $k (qw(91 92 93 123 124 125 126)){
	    if( $self->{-D} ){
		$self->{_font}->[$k] = '';
		_load_char($self, $k) || last;
	    }
	    else{
		#do some reads to discard them
		map(<FLF>, 1 .. $self->{_header}->[1]);
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
	for(my $ord=0; $ord < scalar @{$self->{_font}}; $ord++){
	    for(my $i=1; $i<=$self->{_header}->[1]; $i++ ){
		$len = length($self->{_font}->[$ord]->[$i]);
		if( $self->{_maxLen} > $len ){
		    $len = $self->{_maxLen} - $len;
		    $self->{_font}->[$ord]->[$i] =
			" " x int($len/2) .
			    $self->{_font}->[$ord]->[$i] .
				" " x ($len-int($len/2));
		}
	    }
	    $self->{_font}->[$ord]->[0]->{maxLen} = $self->{_maxLen};
	}
    }

    if( $self->{-m} > -1 && $self->{-m} ne '-0' ){
	for(my $ord=0; $ord < scalar @{$self->{_font}}; $ord++){
	    for(my $i=1; $i<=$self->{_header}->[1]; $i++ ){
		$self->{_font}->[$ord]->[$i] =~
		    s/^\s{0,$self->{_font}->[$ord]->[0]->{wLead}}//;
		$self->{_font}->[$ord]->[$i] =~
		    s/[$self->{_header}->[0]\s]{$self->{_font}->[$ord]->[0]->{wTrail}}$//;
	    }
	}
    }
}

sub _load_char($$){
    my($self, $i) = @_;
    my($length, $wLead, $wTrail,  $end, $line);

    $wLead = $wTrail = $self->{_header}->[2];

    for(my $j=0; $j<$self->{_header}->[1]; $j++){
	$line = local $_ = <FLF> ||
	    carp("Unexpected end of font file") && return 0;

	($end) = /(.)\s*$/;
	if( $wLead && /^(\s+)/ ){
	    $wLead = length($1) < $wLead ? length($1) : $wLead;
	}
	else{
	    $wLead = 0;
	}
	if( $wTrail && /([$self->{_header}->[0]\s]+)$end+\s*$/ ){
	    $wTrail = length($1) < $wTrail ? length($1) : $wTrail;
	}
	else{
	    $wTrail = 0; }
	$length = $length > length($_) ? $length : length($_);
	if( $self->{-m} eq '-0' ){
	    s/$self->{_header}->[0]/ /g;
	    $line = $_;
	    $length -= (s/(^\s+)|(\s+$end*\s*$)//g);
	    $self->{_maxLen} = $length > $self->{_maxLen} ?
		$length : $self->{_maxLen};
	}
	$self->{_font}->[$i] .= $line;
    }
    $self->{_font}->[$i] =~ /(.){2}$/;
    $self->{_font}->[$i] =~ s/$1|\015//g;
    $self->{_font}->[$i] = [{maxLen=>$length-3,
			     wLead=>$wLead,
			     wTrail=>$wTrail},
			    split($/, $self->{_font}->[$i])];
    return 1;
}


sub figify{
    my $self = shift();
    my %opts = @_;
    my($buffer, @text);
    local $_;

    $opts{-w} ||= 80;

    #Do text formatting here...
    if( $opts{-X} ne 'L' ){
	$opts{-X} ||= $self->{_header}->[6] ? 'R' : 'L';
    }
    if( $opts{-X} eq 'R' ){
	$opts{-A} = join('', reverse(split('', $opts{-A})));
    }

    $opts{-A} =~ tr/\t/ /;
    $opts{-A} =~  s%$/%\n%;
    if( $opts{-m} eq '-0' ){
	$Text::Wrap::columns = int($opts{-w} / $self->{_maxLen});
	$opts{-A} = Text::Wrap::wrap('', '', $opts{-A}), "\n";
    }
    else{
	$Text::Wrap::columns = $opts{-w}+1;
	@text = split(//, $opts{-A});
	$opts{-A} = '';
	foreach( @text ){
	    $opts{-A} .= $_ . "\0" x ($self->{_font}->[ord($_)]->[0]->{maxLen}-1);
	}
        $opts{-A} = Text::Wrap::wrap('', '', $opts{-A}), "\n";
	$opts{-A} =~ tr/\0//d;
    }
    @text = split("\n", $opts{-A});


    foreach( @text ){
	s/^\s*//o;
	my @lchars = map(ord($_), split('', $_));
	for(my $i=1; $i<=$self->{_header}->[1]; $i++){
	    my $line;
	    foreach my $lchar (@lchars){
		if( $self->{_font}->[$lchar] ){
		    $line .= $self->{_font}->[$lchar]->[$i];
		}
		else{
		    $line .= $self->{_font}->[32]->[$i];
		}
		if( $self->{-m} ne '-0' ){
		    $line =~ s/$self->{_header}->[0]/ /g; }
	    }


	    #Do some more text formatting here...
	    if( $opts{-x} ne 'l' ){
		$opts{-x} ||= $opts{-X} eq 'R' ? 'r' : 'l';
	    }

	    if( $opts{-x} eq 'c' ){
		$line = " "x(($opts{-w}-length($line))/2) . $line;
	    }
	    if( $opts{-x} eq 'r' ){
		$line = " "x($opts{-w}-length($line)) . $line;
	    }
	    $buffer .= "$line$/";
	}
    }
    return $buffer;
}
package main;
no strict;
use vars qw($A $D $E $I1 $I2 $I3 $L $R $X $c $d $demo $f $help $l $m $r $w $x);
$VERSION = '2.1';
if( $help ){
    eval "use Pod::Text;";
    die("Unable to print man page: $@\n") if $@;
    pod2text(__FILE__);
    exit 0;
}
if($I1){
    die($VERSION*1000, "\n");
}

$font = Text::FIGlet->new(-D=>$D&!$E, -d=>$d, -m=>$m, -f=>$f);

if($I2){
    die("$font->{-d}\n");
}
if($I3){
    die("$font->{-f}\n");
}
if( $demo ){
    print $font->figify(-A=>join('', map(chr($_), 33..127)),
			-X=>($L&&'L')||($R&&'R'),
			-m=>$m,
			-w=>$w,
			-x=>($l&&'l')||($c&&'c')||($r&&'r'));
    exit 0;
}
if( $A ){
    @ARGV = map($_ = $_ eq '' ? $/ : $_, @ARGV);
    print $font->figify(-A=>join(' ', @ARGV),
			-X=>($L&&'L')||($R&&'R'),
			-m=>$m,
			-w=>$w,
			-x=>($l&&'l')||($c&&'c')||($r&&'r'));
}
else{
    Text::FIGlet::croak("Usage: minifig.pl -help") if @ARGV;
    while(<STDIN>){
	print $font->figify(-A=>$_,
			    -X=>($L&&'L')||($R&&'R'),
			    -m=>$m,
			    -w=>$w,
			    -x=>($l&&'l')||($c&&'c')||($r&&'r'));
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
[ B<-E> ]
[ B<-L> ]
[ B<-R> ]
[ B<-X> ]
[ B<-c> ]
[ B<-d=>F<fontdirectory> ]
[ B<-demo> ]
[ B<-f=>F<fontfile> ]
[ B<-help> ]
[ B<-l> ]
[ B<-r> ]
[ B<-w=>I<outputwidth> ]
[ B<-x> ]

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
B<-E>

B<D>  switches  to  the German (ISO 646-DE) character
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
font this is, use the B<-I3> option.

=item B<-m>I<smushmode>

Specifies how FIGlet should ``smush'' and kern consecutive
characters together.  On the command line,
B<-m0> can be useful, as it tells FIGlet to kern characters
without smushing them together.   Otherwise,
this option is rarely needed, as a FIGlet font file
specifies the best smushmode to use with the  font.
B<-m>  is,  therefore,  most  useful to font designers
testing the various  

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

FIGlet home page

 http://st-www.cs.uiuc.edu/users/chai/figlet.html
 http://mov.to/figlet/

FIGlet font files, these can be found at

 http://www.internexus.net/pub/figlet/
 ftp://wuarchive.wustl.edu/graphics/graphics/misc/figlet/
 ftp://ftp.plig.org/pub/figlet/

=head1 SEE ALSO

L<figlet>, L<Text::FIGlet>, L<figlet.pl>

=head1 AUTHOR

Jerrad Pierce <jpierce@cpan.org>|<webmaster@pthbb.rg>

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
