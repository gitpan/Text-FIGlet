package Text::FIGlet;
$VERSION = '1.06';
use 5;
use Carp qw(carp croak);
use File::Spec;
use File::Basename qw(basename);
use Text::Wrap;
use strict;
use vars '$REwhite';

sub new{
  shift();
  my $self = {@_};

  $self->{-f} ||= $ENV{FIGFONT} || 'standard';
  $self->{-d} ||= $ENV{FIGLIB}  || '/usr/games/lib/figlet/';
  #translate dir seperator in FIGLIB
  _load_font($self);
  bless($self);
  return $self;
}

sub _load_font{
  my $self = shift();
  my(@header, $header, $font);
  local $_;

  $self->{_file} = $font = (-f $self->{-f} && $self->{-f})||
    (-f File::Spec->rel2abs($self->{-f}) && File::Spec->rel2abs($self->{-f}))||
      File::Spec->catfile($self->{-d}, $self->{-f});
  open(FLF, $font) || open(FLF, "$font.flf") || croak("$!: $font");

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
  <FLF> for 1 .. $header[5] || carp("Unexpected end of font file") && last;

  $REwhite = qr/(^?:\s+)|(?:\s+(?=$header[0]*\s*$))/;
  #Get ASCII characters
  foreach my $i(32..126){
    &_load_char($self, $i) || last;
  }

  #German characters?
  unless( eof(FLF) ){
    foreach my $k (qw(91 92 93 123 124 125 126)){
      if( $self->{-D} ){
	$self->{_font}->[$k] = '';
	&_load_char($self, $k) || last;
      }
      else{
	#do some reads to discard them
	<FLF> for 1 .. $header[1];
      }
    }
  }

  #Extended characters, read extra line to get code
  until( eof(FLF) ){
    $_ = <FLF> || carp("Unexpected end of font file") && last;
    /^(\w+)/;
    last unless $1;
    &_load_char($self, $1 =~ /^0x/ ? hex $1 : $1) || last;
  }
  close(FLF);

  if( $self->{-m} eq '-0' ){
    my $pad;
    for(my $ord=0; $ord < scalar @{$self->{_font}}; $ord++){
      foreach my $i (3..$header[1]+2){
        next unless exists($self->{_font}->[$ord]->[2]);
  	$pad = $self->{_maxLen} - length($self->{_font}->[$ord]->[$i]);
  	$self->{_font}->[$ord]->[$i] = " " x int($pad/2) .
  	  $self->{_font}->[$ord]->[$i] . " " x ($pad-int($pad/2));
      }
    }
  }

  if( $self->{-m} > -1 && $self->{-m} ne '-0' ){
    for(my $ord=0; $ord < scalar @{$self->{_font}}; $ord++){
      foreach my $i (3..$header[1]+2){
	 $self->{_font}->[$ord]->[$i] =~
	   s/^\s{0,$self->{_font}->[$ord]->[1]}//;
	 $self->{_font}->[$ord]->[$i] =~
	   s/[$header[0]\s]{$self->{_font}->[$ord]->[2]}$//;
      }
    }
  }
}

sub _load_char{
  my($self, $i) = @_;
  my($length, $wLead, $wTrail, $end, $line, $l);
  
  $wLead = $wTrail = $self->{_header}->[3];
  
  my $REtrail;
  foreach my $j (0..$self->{_header}->[1]-1){
    $line = $_ = <FLF> ||
      carp("Unexpected end of font file") && return 0;
    #This is the end.... this is the end my friend
    unless( $REtrail ){
      /(.)\s*$/;
      $end = $1;
      $REtrail = qr/([ $self->{_header}->[0]]+)$end{1,2}\s*$/;
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
      $wTrail = 0; }
    $length   = $l if ($l = length($_)-1-(s/$end/$end/og)) > $length;
    $self->{_font}->[$i] .= $line;
  }
  $self->{_maxLen} = $length if $self->{_maxLen} < $length;


  #Ideally this would be /o but then all figchar's must have same EOL
  $self->{_font}->[$i] =~ s/$end|\015//g;
  $self->{_font}->[$i] = [$length,#maxLen
			  $wLead, #wLead
			  $wTrail,#wTrail
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
	$Text::Wrap::columns = int($opts{-w} / $self->{_maxLen})+1;
	$Text::Wrap::columns =2 if $Text::Wrap::columns < 2;
	$opts{-A} = Text::Wrap::wrap('', '', $opts{-A});
    }
    else{
	$Text::Wrap::columns = $opts{-w}+1;
	unless( $opts{-w} == 1 ){
	  @text = split(//, $opts{-A});
	  $opts{-A} = '';
	  foreach( @text ){
	    $opts{-A} .= "\0" x ($self->{_font}->[ord($_)]->[0]-1) . $_;
	  }
	}
        $opts{-A} = Text::Wrap::wrap('', '', $opts{-A}), "\n";
	$opts{-A} =~ tr/\0//d;
    }
    @text = split("\n", $opts{-A});


    foreach( @text ){
	s/^\s*//o;
	my @lchars = map(ord($_), split('', $_));
	foreach my $i (3..$self->{_header}->[1]+2){
	    my $line;
	    foreach my $lchar (@lchars){
		if( $self->{_font}->[$lchar] ){
		    $line .= $self->{_font}->[$lchar]->[$i];
		}
		else{
		    $line .= $self->{_font}->[32]->[$i];
		}
		$line =~ s/$self->{_header}->[0]/ /g;
	    }


	    #Do some more text formatting here... (smushing)
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
__END__
=pod

=head1 NAME

Text::FIGlet - a perl module to provide FIGlet abilities, akin to banner

=head1 SYNOPSIS

 my $font = Text::FIGlet-E<gt>new(-f=>"doh");
 $font->figify(-A=>"Hello World");

=head1 DESCRIPTION

But why?

Because I could.

But why?

Because I like FIGlet and Perl.

But why? In Bob's name WHY?! What purpose could it serve?

If you want something more substantive imagine:

=over

=item * Run Apache with mod_perl

=item * In F<startup.pl> create a Text::FIGlet object

=item * figify text for the heads of Directory listings,
      and you look like an FTP site ;-)

Or not, I just make the scissors, now run along.

=back 

=head1 OPTIONS

C<new>

=over

=item B<-D=E<gt>>I<boolean>

If true, switches  to  the German (ISO 646-DE) character
set.  Turns `[', `\' and `]' into umlauted A, O and
U,  respectively.   `{',  `|' and `}' turn into the
respective lower case versions of these.  `~' turns
into  s-z. Assumin, of course, that the font author
included these characters. This option is deprecated, which means it
may not appear in upcoming versions of B<Text::FIGlet>.

=item B<-d=E<gt>>F<fontdir>

Whence to load the font.

Defaults to F</usr/games/lib/figlet>

=item B<-f=E<gt>>F<fontfile>

The font to load.

Defaults to F<standard>

=item B<-m=E<gt>>I<smushmode>

Specifies how B<Text::FIGlet> should ``smush'' and kern consecutive
characters together.  On the command line,
B<-m0> can be useful, as it tells FIGlet to kern characters
without smushing them together.   Otherwise,
this option is rarely needed, as a B<Text::FIGlet> font file
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

=back

C<figify>

=over

=item B<-A=E<gt>>I<text>

The text to transmogrify.

=item B<-X=E<gt>>[LR]

These  options  control whether FIGlet prints
left-to-right or  right-to-left. B<L> selects
left-to-right printing. B<R> selects right-to-left printing.
The default is to use whatever is specified in the font file.

=item B<-x=E<gt>>[lrc]

These  options  handle  the justification of B<Text::FIGlet>
output.  B<c> centers the  output  horizontally.   B<l>
makes  the  output  flush-left.  B<r> makes it flush-
right.  The default sets the justification according
to whether left-to-right or right-to-left text
is selected.  Left-to-right  text  will  be  flush-
left, while right-to-left text will be flush-right.
(Left-to-rigt versus right-to-left  text  is  controlled by B<-X>.)

=item B<-w=E<gt>>I<outputwidth>

The output width, output text is wrapped to this value by breaking the
input on whitspace where possible. There are two special width values

 -1 the text is not wrapped.
  1 the text is wrapped after very character.

Defaults to 80

=back

=head1 EXAMPLES

C<perl -MText::FIGlet -e
'print Text::FIGlet-E<gt>new()-E<gt>figify(-A=E<gt>"Hello World")'>

=head1 ENVIRONMENT

B<Text::FIGlet> will make use of these environment variables if present

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

L<figlet>

=head1 CAVEATS

=over

=item $/ is used to 

=over

=item split incoming text into seperate lines.

=item create the output string

=item parse the font file

=back

=back

Consequently, make sure it is set appropriately i.e.;
 Don't mess with it, B<perl> sets it correctly for you.

=head1 AUTHOR

Jerrad Pierce <jpierce@cpan.org>|<webmaster@pthbb.org>

=cut
