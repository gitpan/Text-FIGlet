#!/mit/belg4mit/arch/sun4x_59/bin/perl -w
package Text::FIGlet;
require 5;
use constant PRIVb => 0xF0000; #Map negative characters into Unicode's
use constant PRIVe => 0xFFFFD; #Private area
use strict;
use vars qw'$VERSION %RE';
use Carp qw(carp croak);
$VERSION = 2.02; #2.02


$] >= 5.008 ? eval "use Encode;" : eval "sub Encode::_utf8_off {};";
%RE = (
       UTFchar => qr/([\xC0-\xDF].|[\xE0-\xEF]..|[\xF0-\xFF]...|.)/,
       bytechar=> qr/(.)/,
       no      => qr/(-?)((0?)(?:x[\da-fA-F]+|\d+))/,
       );

sub new {
  local $_;
  my $proto = shift;
  my($class, @isect, %count);
  my %class = (
	       -f => 'Font',
	       -C => 'Control'
	       );

  $count{$_}++ for (keys %{ {@_} }, keys %class);
  $count{$_} == 2 && push(@isect, $_) for keys %count;
  
  croak("Cannot new both -C and -f") if scalar @isect > 1;

  $class = shift(@isect) || '-f';
  $class = 'Text::FIGlet::' . $class{$class};
  $class->new(@_);
}

sub _no{
  my($one, $two, $thr, $over) = @_;

  my $val = ($one ? -1 : 1) * ( $thr eq 0 ? oct($two) : $two);

  #+2 is to map -2 to offset zero (-1 is forbidden, modern systems have no -0)
  $val += PRIVe + 2 if $one;
  if( $one && $over && $val < PRIVb ){
    carp("Extended character out of bounds");
    return 0;
  }

  $val;
}

sub _UTFord{
  my $str = shift || $_;
  my $len = length ($str);

  return ord($str) if $len == 1;
  #This is a FIGlet specific error value
  return 128       if $len > 4 || $len == 0;

  my @n = unpack "C*", $str;
  $str  = (($n[-2] & 0x3f) <<  6) + ($n[-1] & 0x3f);
  $str += (($n[-3] & 0x1f) << 12) if $len ==3;
  $str += (($n[-3] & 0x3f) << 12) if $len ==4;
  $str += (($n[-4] & 0x0f) << 18) if $len == 4;
  return $str;
}
package Text::FIGlet::Control;
require 5;
use strict;
use vars '$VERSION';
use Carp 'croak';
use File::Basename 'fileparse';
use File::Spec;
$VERSION = 2.01;

sub new{
  my $proto = shift;
  my $self = {-C=>[]};
  local($_, *FLC);

  my $code = '';
  my(@t_pre, @t_post);
  while( @_ ){
    my $s = shift;
    $self->{-d} = shift if $s eq '-d';
    push(@{$self->{-C}}, shift) if $s eq '-C';
  }
  $self->{-d} ||= $ENV{FIGLIB}  || '/usr/games/lib/figlet/';


#  my $no = qr/0x[\da-fA-F]+|\d+/;

  foreach my $flc ( @{$self->{-C}} ){
    my($file, $path) = fileparse($flc, '\.flc');
    $path = $self->{-d} if $path eq './' && index($flc, './') < 0;
    
    open(FLC, File::Spec->catfile($path, $file.'.flc')) || croak("$!: $flc");
    while(<FLC>){
      next if /^flc2a|\s*#|^\s*$/;

      #XXX Is this adequate?
      $code .= 'use utf8;' if /^\s*u/;

      if( /^\s*$Text::FIGlet::RE{no}\s+$Text::FIGlet::RE{no}\s*/ ){
	#Only needed for decimals?!

	push @t_pre,  sprintf('\\x{%x}', Text::FIGlet::_no($1, $2, $3));
	push @t_post, sprintf('\\x{%x}', Text::FIGlet::_no($4, $5, $6));
      }
      elsif( /^\s*t\s+\\?$Text::FIGlet::RE{no}(?:-\\$Text::FIGlet::RE{no})?\s+\\?$Text::FIGlet::RE{no}(?:-\\$Text::FIGlet::RE{no})?\s*/ ){
	push @t_pre,  sprintf( '\\x{%x}', Text::FIGlet::_no( $1, $2, $3));
	push @t_post, sprintf( '\\x{%x}', Text::FIGlet::_no( $7, $8, $9));
	$t_pre[-1] .= sprintf('-\\x{%x}', Text::FIGlet::_no( $4, $5, $6)) if$5;
	$t_post[-1].= sprintf('-\\x{%x}', Text::FIGlet::_no($10,$11,$12))if$11;
      }
      elsif( /^\s*t\s+([^\s](?:-[^\s])?)\s+([^\s](?:-[^\s])?)\s*/ ){
	push @t_pre,  $1;
	push @t_post, $2;
      }
      if( /^\s*f/ || eof(FLC) ){
	@{$_} = map { s%/%\\/%g, $_ } @{$_} for( \@t_pre, \@t_post );
	$code  .= 'tr/' . join('', @t_pre) . '/' . join('', @t_post) . '/;';
	@t_pre = @t_post = ();
      }
    }
    close(FLC);
  }
  $self->{_sub} = eval "sub { local \$_ = shift; $code; return \$_ }";
  bless($self);
}

sub tr($){
  my $self = shift;
  $self->{_sub}->( shift || $_ );
}
1;
package Text::FIGlet::Font;
require 5;
use strict;
use vars qw($REwhite $VERSION);
use Carp qw(carp croak);
use File::Spec;
use File::Basename qw(fileparse);
use Text::Wrap;
$VERSION = 2.02;

sub new{
  shift();
  my $self = {_maxLen=>0, @_};
  $self->{-f} ||= $ENV{FIGFONT} ;
  $self->{-d} ||= $ENV{FIGLIB}  || '/usr/games/lib/figlet/';
  _load_font($self);
  bless($self);
}

sub _load_font{
  my $self = shift();
  my $font = $self->{_font} = [];
  my(@header, $header, $path);
  local($_, *FLF);

  if ( $self->{-f} ) {
  ($self->{_file}, $path) = fileparse($self->{-f}, '\.flf');
  $path = $self->{-d} if $path eq './' && index($self->{-f}, './') < 0;
  $self->{_file} = File::Spec->catfile($path, $self->{_file}.'.flf');
  open(FLF, $self->{_file}) || croak("$!: $self->{_file}");
  } else {
    *FLF = *main::DATA;
    while ( <FLF> ) {
      last if /__END__/;
    }
  }


  chomp($header = <FLF>);
  croak("Invalid figlet 2 font") unless $header =~ /^flf2/;

  #flf2ahardblank height up_ht maxlen smushmode cmt_count rtol
  @header = split(/\s+/, $header);
  $header[0] =~ s/^flf2.//;
  $header[0] = quotemeta($header[0]);
  $self->{_header} = \@header;

  unless( exists($self->{-m}) && defined($self->{-m}) && $self->{-m} ne '-2' ){
    $self->{-m} = $header[4];
  }

  #Discard comments
  <FLF> for 1 .. $header[5] || carp("Unexpected end of font file") && last;

#  $REwhite = qr/(?:^\s+)|(?:\s+(?=$header[0]*\s*$))/;
  #Get ASCII characters
  foreach my $i(32..126){
    &_load_char($self, $i) || last;
  }

  #German characters?
  unless( eof(FLF) ){
    my %D =(91=>196, 92=>214, 93=>220, 123=>228, 124=>246, 125=>252, 126=>223);

    foreach my $k ( sort {$a <=> $b} keys %D ){
      &_load_char($self, $D{$k}) || last;
    }
    if( $self->{-D} ){
      $font->[$_] = $font->[$D{$_}] for keys %D;
    }
  }


  #XXX negative character codes!!!
  #Extended characters, read extra line to get code
  until( eof(FLF) ){
    $_ = <FLF> || carp("Unexpected end of font file") && last;

    /^\s*$Text::FIGlet::RE{no}/;
    last unless $2;

    my $val = Text::FIGlet::_no($1, $2, $3, 1);

    #Clobber German chars
    $font->[$val] = '';

    &_load_char($self, $val) || last;
  }
  close(FLF);

  if( $self->{-m} eq '-0' ){
    my $pad;
    for(my $ord=0; $ord < scalar @{$font}; $ord++){
#     foreach my $i (3..$header[1]+2){
      foreach my $i (-$header[1]..-1){
	#XXX Could we optimize this to next on the outer loop?
        next unless exists($font->[$ord]->[2]);

	# The if protects from a a 5.6(.0)? bug
	$font->[$ord]->[$i] =~ s/^\s{1,$font->[$ord]->[1]}//
	  if $font->[$ord]->[1];

  	$pad = $self->{_maxLen} - length($font->[$ord]->[$i]);
  	$font->[$ord]->[$i] = " " x int($pad/2) .
  	  $font->[$ord]->[$i] . " " x ($pad-int($pad/2));
      }
    }
  }

  if( $self->{-m} == -1 ){
    for(my $ord=32; $ord < scalar @{$font}; $ord++){
      foreach my $i (-$header[1]..-1){
	#XXX Could we optimize this to next on the outer loop?
	next unless $font->[$ord]->[$i];
	# The if protects from a a 5.6(.0)? bug
	$font->[$ord]->[$i] =~ s/^\s{1,$font->[$ord]->[1]}//
	  if $font->[$ord]->[1];
        substr($font->[$ord]->[$i], 0, 0, ' 'x$font->[$ord]->[1]);
        $font->[$ord]->[$i] .= ' 'x$font->[$ord]->[2];
      }
    }
  }

  if( $self->{-m} > -1 && $self->{-m} ne '-0' ){
    for(my $ord=32; $ord < scalar @{$font}; $ord++){
      foreach my $i (-$header[1]..-1){
	#XXX Could we optimize this to next on the outer loop?
	next unless $font->[$ord]->[$i];
	# The if protects from a a 5.6(.0)? bug
	$font->[$ord]->[$i] =~ s/^\s{1,$font->[$ord]->[1]}//
	  if $font->[$ord]->[1];
      }
    }
  }
}

sub _load_char{
  my($self, $i) = @_;
  my $font = $self->{_font};
  my($length, $wLead, $wTrail, $end, $line, $l) = 0;
  
  $wLead = $wTrail = $self->{_header}->[3];
  
  my $REtrail;
  foreach my $j (0..$self->{_header}->[1]-1){
    $line = $_ = <FLF> ||
      carp("Unexpected end of font file") && return 0;
    #This is the end.... this is the end my friend
    unless( $REtrail ){
      /(.)\s*$/;
      $end = $1;
#XXX  $REtrail = qr/([ $self->{_header}->[0]]+)$end{1,2}\s*$/;
      $REtrail = qr/([ $self->{_header}->[0]]+)$end$end?\s*$/;
    }
    if( $wLead && s/^(\s+)// ){
      $wLead  = $l if ($l = length($1)) < $wLead;
    }
    else{
      $wLead  = 0;
    }
    if( $wTrail && /$REtrail/ ){
      $wTrail = $l if ($l = length($1)) < $wTrail;
    }
    else{
      $wTrail = 0;
    }
    $length = $l if ($l = length($_)-1-(s/$end+$/$end/mog)) > $length;
    $font->[$i] .= $line;
  }
  #XXX :-/ stop trying at 125 in case of map in ~ or extended....
  $self->{_maxLen} = $length if $i < 126 && $self->{_maxLen} < $length;

  #Ideally this would be /o but then all figchar's must have same EOL
  $font->[$i] =~ s/$end|\015//g;
  $font->[$i] = [$length,#maxLen
			  $wLead, #wLead
			  $wTrail,#wTrail
			  split(/\r|\r?\n/, $font->[$i])];
  return 1;
}

sub figify{
    my $self = shift();
    my $font = $self->{_font};
    my %opts = (-A=>'', -X=>'', -x=>'', -w=>'', -U=>0, @_);
    my @buffer;
    local $_;

    $opts{-w} ||= 80;
    $opts{-U} || Encode::_utf8_off($opts{-A}) if $] >= 5.008;

    #Do text formatting here...
    $opts{-X} ||= $self->{_header}->[6] ? 'R' : 'L';
    if( $opts{-X} eq 'R' ){
	$opts{-A} = join('', reverse(split('', $opts{-A})));
    }

    $opts{-A} =~ tr/\t/ /;
    $opts{-A} =~  s%$/%\n%;
    if( exists($self->{-m}) && $self->{-m} eq '-0' ){
	$Text::Wrap::columns = int($opts{-w} / $self->{_maxLen})+1;
	$Text::Wrap::columns =2 if $Text::Wrap::columns < 2;
	$opts{-A} = Text::Wrap::wrap('', '', $opts{-A});
    }
    #No-wrap test, missing pre 2.00 :-(
    elsif( $opts{-w} > 0 ){
	$Text::Wrap::columns = $opts{-w}+1;
	unless( $opts{-w} == 1 ){
	  ($_, $opts{-A}) = ($opts{-A}, '');
#	  $opts{-A} .= "\0"x(($font->[ ord($1) ]->[0]||1)-1) . $1 while /(.)/g;
	  while( $opts{-U} ?
		 /$Text::FIGlet::RE{UTFchar}/g :
		 /$Text::FIGlet::RE{bytechar}/g ){
	    $opts{-A} .= "\0"x(($font->[
					$opts{-U} ? Text::FIGlet::_UTFord($1) : ord($1)
				       ]->[0]||1)-1) . $1
	  }
	}
	#XXX pre 5.8 Text::Wrap is not Unicode happy?
        $opts{-A} = Text::Wrap::wrap('', '', $opts{-A});
	$opts{-A} =~ tr/\0//d;
    }

    foreach( split("\n", $opts{-A}) ){
      my @lchars;
      s/^\s*//o;
#      push(@lchars, ord $1) while /(.)/g;
      while( $opts{-U} ?
	     /$Text::FIGlet::RE{UTFchar}/g :
	     /$Text::FIGlet::RE{bytechar}/g ){
	push @lchars, ($opts{-U} ? Text::FIGlet::_UTFord($1) : ord($1));
      }

      foreach my $i (3..$self->{_header}->[1]+2){
	my $line='';
	foreach my $lchar (@lchars){
	  if( $font->[$lchar] ){
	    $line .= $font->[$lchar]->[$i] if $font->[$lchar]->[$i];
	  }
	  else{
	    $line .= $font->[32]->[$i];
	  }
	  #XXX
	  # /o because we can't tr ... is this a problem across objects?
	  $line =~ s/$self->{_header}->[0]/ /og;
	}
	
	
	#Do some more text formatting here... (smushing)
	$opts{-x} ||= $opts{-X} eq 'R' ? 'r' : 'l';
	if( $opts{-x} eq 'c' ){
	  $line = " "x(($opts{-w}-length($line))/2) . $line;
	}
	if( $opts{-x} eq 'r' ){
	  $line = " "x($opts{-w}-length($line)) . $line;
	}
	push @buffer, $line;
      }
    }
    return wantarray ? @buffer : join($/, @buffer).$/;
}
1;
#!/mit/belg4mit/arch/sun4x_59/bin/perl -w
package main;
use strict;
use vars '$VERSION';
$VERSION = 2.1.2;

my %opts;
$opts{-C} = [];
$opts{$_} = undef for
  qw(A D E L R U X c e h help -help l r x);
$opts{$_} = "0 but true" for
  qw(I d f m w);
for (my $i=0; $i <= scalar @ARGV; $i++) {
  last unless exists($ARGV[$i]);
  shift && last if $ARGV[$i] eq '--';
  if( $ARGV[$i]  =~ /^-N$/ ) {
    shift; $i--;
    $opts{-C} = [];
  }
  if( $ARGV[$i]  =~ /^-C=?(.*)/ ) {
    shift; $i--;
    $opts{-C} = [ @{$opts{-C}}, 
		  defined($1) && $1 ne '' ?
		  $1 : defined($opts{-C}) ? do{$i--; shift} : undef
		];
    next;
  }
  foreach my $key ( sort { length($b)-length($a) } keys %opts) {
    if( $ARGV[$i] =~ /^-$key=?(.*)/ ){
      shift; $i--;
      $opts{$key} = defined($1) && $1 ne '' ?
	$1 : defined($opts{$key}) ? do{$i--; shift} : 1;
      last;
    }
  }
}
defined($_) && $_ eq '0 but true' && ($_ = undef) for values %opts;
if( $opts{help}||$opts{h}||$opts{-help} ){
    eval "use Pod::Text;";
    die("Unable to print man page: $@\n") if $@;
    pod2text(__FILE__);
    exit 0;
}

$opts{I} ||= 0;
if( $opts{I} == 1 ){
  my @F = unpack("c*", $VERSION);
  die(10_000 * $F[0] + 100 * $F[1] +$F[2], "\n");
}

my $font = Text::FIGlet->new(-D=>$opts{D}&&!$opts{E},
			  -d=>$opts{d},
			  -m=>$opts{m},
			  -f=>$opts{f});
@_ = map { -C=> $_ } @{$opts{-C}} if scalar @{$opts{-C}};
my $ctrl = Text::FIGlet->new( @_,
			     -d=>$opts{d}) if @_;

if( $opts{I} == 2 ){
    die("$font->{-d}\n");
}
if( $opts{I} == 3 ){
    die("$font->{-f}\n");
}

my %figify = (
	      -U=>$opts{U},
	      -X=>($opts{L}&&'L')||($opts{R}&&'R'),
	      -m=>$opts{m},
	      -w=>$opts{w},
	      -x=>($opts{l}&&'l')||($opts{c}&&'c')||($opts{r}&&'r') );
croak("figlet.pl: cannot use both -A and -e") if $opts{A} && $opts{e};
if( $opts{e} ){
    $opts{A} = 1;
    @ARGV = eval "@ARGV";
    croak($@) if $@;
}
if( $opts{A} ){
    $_ = join(' ', map($_ = $_ eq '' ? $/ : $_, @ARGV));
    print scalar $font->figify(-A=>($ctrl ? $ctrl->tr() : $_), %figify);
    exit 0;
}
else{
    Text::FIGlet::croak("Usage: figlet.pl -help\n") if @ARGV;
    print scalar $font->figify(-A=>($ctrl ? $ctrl->tr() : $_), %figify)
      while <STDIN>;
}
__DATA__
=pod

=head1 NAME

minifig.pl - display large characters made up of ordinary screen characters

=head1 SYNOPSIS

B<minifig.pl>
[ B<-A> ]
[ B<-C> ]
[ B<-D> ]
[ B<-E> ]
[ B<-L> ]
[ B<-N> ]
[ B<-R> ]
[ B<-U> ]
[ B<-X> ]
[ B<-c> ]
[ B<-d=>F<fontdirectory> ]
[ B<-e> C<EXPR>]
[ B<-f=>F<fontfile> ]
[ B<-help> ]
[ B<-l> ]
[ B<-r> ]
[ B<-w=>I<outputwidth> ]
[ B<-x> ]

=head1 DESCRIPTION

B<minifig.pl> prints its input using large characters made up of
ordinary screen characters. B<minifig.pl> output is generally
reminiscent of the sort of I<signatures> many people like
to put at the end of e-mail and UseNet messages. It is
also reminiscent of the output of some banner programs,
although it is oriented normally, not sideways.

B<minifig.pl> can print in a variety of fonts, both left-to-right
and right-to-left, with adjacent characters kerned and
I<smushed> together in various ways. B<minifig.pl> fonts are
stored in separate files, which can be identified by the
suffix I<.flf>. Most B<minifig.pl> font files will be stored in
FIGlet's default font directory.

B<minifig.pl> can also use control files, which tell it to
map certain input characters to certain other characters,
similar to the Unix tr command. Control files can be
identified by the suffix F<.flc>. Most FIGlet control
files will be stored in FIGlet's default font directory.

=head1 OPTIONS

=over

=item B<-A>

All Words. Once the - arguments are read, all
words remaining on the command line are used
instead of standard input to print letters. Allows
shell scripts to generate large letters without
having to dummy up standard input files.

An empty character, obtained by two sequential and
empty quotes, results in a line break.

To include text begining with - that might otherwise
appear to be an invalid argument, use the argument --

=item B<-C>=F<controlfile>
B<-N>

These options deal with FIGlet F<controlfiles>. A F<controlfile> is a file
containing a list of commands that FIGlet executes each time it reads a
character. These commands can map certain input characters to other characters,
similar to the Unix tr command or the FIGlet B<-D> option. FIGlet maintains
a list of F<controlfiles>, which is empty when FIGlet starts up. B<-C> adds
the given F<controlfile> to the list. B<-N> clears the F<controlfile> list,
cancelling the effect of any previous B<-C>. FIGlet executes the commands in
all F<controlfiles> in the list. See the file F<figfont.txt>, provided with
FIGlet, for details on how to write a F<controlfile>.

=item B<-D>
B<-E>

B<-E> is the default, and a no-op.

B<-D>  switches  to  the German (ISO 646-DE) character
set.  Turns `[', `\' and `]' into umlauted A, O and
U,  respectively.   `{',  `|' and `}' turn into the
respective lower case versions of these.  `~' turns
into  s-z.

These options are deprecated, which means they may soon
be removed. The modern way to achieve this effect is with
control files, see B<-C>.

=item B<-I>I<infocode>

These options print various information about FIGlet, then exit.

=over

=item 1 Version (integer).

This will print the version of your copy of FIGlet as a decimal integer.
The main version number is multiplied by 10000, the sub-version number is
multiplied by 100, and the sub-sub-version number is multiplied by 1.
These are added together, and the result is printed out. For example,
FIGlet 2.1.2 will print ``20102''. If there is ever a version 2.1.3,
it will print ``20103''.  Similarly, version 3.7.2 would print ``30702''.
These numbers are guaranteed to be ascending, with later versions having
higher numbers.

=item 2 Default font directory.

This will print the default font directory. It is affected by the -d option.

=item 3 Font.

This will print the name of the font FIGlet would use.
It is affected by the B<-f> option. This is not a filename;
the I<.flf> suffix is not printed.

=back

=item B<-L>
B<-R>
B<-X>

These options control whether FIGlet prints
left-to-right or right-to-left. B<-L> selects
left-to-right printing. B<-R> selects right-to-left printing.
B<-X> (default) makes FIGlet use whichever is specified
in the font file.

=item B<-U>

Process input as Unicode, if you use a control file with the C<u>
directive unicode processing is automagically enabled for any text
processed with that control.

=item B<-c>
B<-l>
B<-r>
B<-x>

These options handle the justification of FIGlet
output. B<-c> centers the output horizontally. B<-l>
makes the output flush-left. B<-r> makes it flush-right.
B<-x> (default) sets the justification according
to whether left-to-right or right-to-left text
is selected. Left-to-right text will be flush-left,
while right-to-left text will be flush-right.
(Left-to-rigt versus right-to-left text is controlled by B<-L>,
B<-R> and B<-X>.)

=item B<-d>=F<fontdirectory>

Change the default font directory. FIGlet looks
for fonts first in the default directory and then
in the current directory. If the B<-d> option is not
specified, FIGlet uses the directory that was specified
when it was compiled. To find out which
directory this is, use the B<-I2> option.

=item B<-e> C<EXPR>

Evaluates the remaining arguments as perl and processes the results.
This can be especially useful for retrieving Unicode characters.

=item B<-f>=F<fontfile>

Select the font. The I<.flf> suffix may be left off
of fontfile, in which case FIGlet automatically
appends it. FIGlet looks for the file first in the
default font directory and then in the current
directory, or, if fontfile was given as a full
pathname, in the given directory. If the B<-f> option
is not specified, FIGlet uses the font that was
specified when it was compiled. To find out which
font this is, use the B<-I3> option.

=item B<-m=E<gt>>I<smushmode>

Specifies how B<Text::FIGlet::Font> should ``smush'' and kern consecutive
characters together. On the command line,
B<-m0> can be useful, as it tells FIGlet to kern characters
without smushing them together. Otherwise,
this option is rarely needed, as a B<Text::FIGlet::Font> font file
specifies the best smushmode to use with the font.
B<-m> is, therefore, most useful to font designers
testing the various smushmodes with their font.
smushmode can be -2 through 63.

=over

=item S<-2>

Get mode from font file (default).

Every FIGlet font file specifies the best smushmode to use with the font.
This will be one of the smushmodes (-1 through 63) described in the following
paragraphs.

=item S<-1>

No smushing or kerning.

Characters are simply concatenated together.

=item S<-0>

Fixed width.

This will pad each character in the font such that they are all a consistent
width. The padding is done such that the character is centered in it's "cell",
and any odd padding is the trailing edge.

=item S<0>

Kern only.

Characters are pushed together until they touch.

=back

=item B<-w>=I<outputwidth>

These options control the outputwidth, or the
screen width FIGlet assumes when formatting its
output. FIGlet uses the outputwidth to determine
when to break lines and how to center the output.
Normally, FIGlet assumes 80 columns so that people
with wide terminals won't annoy the people they e-mail
FIGlet output to. B<-w> sets the outputwidth 
to the given integer. An outputwidth of 1 is a
special value that tells FIGlet to print each non-
space character, in its entirety, on a separate line,
no matter how wide it is. Another special outputwidth
is -1, it means to not warp.

=back

=head1 EXAMPLES

C<minifig.pl -A Hello "" World>

=head1 ENVIRONMENT

B<minifig.pl> will make use of these environment variables if present

=over

=item FIGFONT

The default font to load.
If undefined the default is F<minifig.flf>
It should reside in the directory specified by FIGLIB.

=item FIGLIB

The default location of fonts.
If undefined the default is F</usr/games/lib/figlet>

=back

=head1 FILES

FIGlet font files are available at

  ftp://ftp.figlet.org/pub/figlet/

=head1 BUGS

Under pre 5.8 perl B<-e> may munge the first character if it is Unicode,
this is a bug in perl itself. The output is usually:

=over

=item 197  LATIN CAPITAL LETTER A WITH RING ABOVE

=item 187  RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK

=back

    o   \\ 
   /_\   >>
  /   \ // 

If this occurs, prepend the sequence with a null.

=head1 SEE ALSO

L<Text::FIGlet>, L<figlet(6)>, L<banner(6)>, L<http://www.figlet.org|>

=head1 AUTHOR

Jerrad Pierce <jpierce@cpan.org>|<webmaster@pthbb.org>

=cut
__END__
flf2a$ 4 3 10 0 10 0 1920
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
