package Text::FIGlet::Font;
require 5;
use strict;
use vars qw($REwhite $VERSION);
use Carp qw(carp croak);
use File::Spec;
use File::Basename qw(fileparse);
use Text::Wrap;
$VERSION = 2.00;

sub new{
  shift();
  my $self = {_maxLen=>0, @_};
  $self->{-f} ||= $ENV{FIGFONT} || 'standard';
  $self->{-d} ||= $ENV{FIGLIB}  || '/usr/games/lib/figlet/';
  _load_font($self);
  bless($self);
}

sub _load_font{
  my $self = shift();
  my $font = $self->{_font} = [];
  my(@header, $header, $path);
  my($lochar, $hichar) = (0, 0xFFFFFFFF);
  local($_, *FLF);

#MAGIC minifig0
  ($self->{_file}, $path) = fileparse($self->{-f}, '\.flf');
  $path = $self->{-d} if $path eq './' && index($self->{-f}, './') < 0;
  $self->{_file} = File::Spec->catfile($path, $self->{_file}.'.flf');
  open(FLF, $self->{_file}) || croak("$!: $self->{_file}");
#MAGIC minifig1

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
    my %D =(196=>91, 214=>92, 220=>93, 228=>123, 246=>124, 252=>125, 223=>126);

    foreach my $k ( keys %D ){
      &_load_char($self, $k) || last;
    }
    if( $self->{-D} ){
      foreach my $k ( keys %D ){
	$font->[$D{$k}] = $font->[$k];
      }
    }
  }


  #XXX negative character codes!!!
  #Extended characters, read extra line to get code
  until( eof(FLF) ){
    $_ = <FLF> || carp("Unexpected end of font file") && last;

    /^\s*$Text::FIGlet::RE{no}/;
    last unless $2;

    my $val = Text::FIGlet::_no($1, $2, $3, 1);

    ($lochar = $lochar < $val ? $val : $lochar) unless $1;
    ($hichar = $hichar < $val ? $hichar : $val ) if $1;

    #Clobber German chars
    $font->[$val] = '';
    &_load_char($self, $val) || last;
  }
  close(FLF);

  if( $self->{-m} eq '-0' ){
    my $pad;
    for(my $ord=0; $ord < scalar @{$font}; $ord++){
      $ord = $hichar-1 if $ord == $lochar;
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
      $ord = $hichar-1 if $ord == $lochar;
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
      $ord = $hichar-1 if $ord == $lochar;
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
__END__
=pod

=head1 NAME

Text::FIGlet::Font - text generation for Text::FIGlet

=head1 SYNOPSIS

  use Text::FIGlet;

  my $font = Text::FIGlet->new(-f=>"doh");

  print $font->figify(-A=>"Hello World");

=head1 DESCRIPTION

Text::FIGlet::Font reproduces its input using large characters made up of
ordinary screen characters. Text::FIGlet::Font output is generally
reminiscent of the sort of I<signatures> many people like to put at the
end of e-mail and UseNet messages. It is also reminiscent of the output
of some banner programs, although it is oriented normally, not sideways.

Text::FIGlet::Font can print in a variety of fonts, both left-to-right and
right-to-left, with adjacent characters kerned and I<smushed> together in
various ways. FIGlet fonts are stored in separate files, which can be
identified by the suffix I<.flf>. Most FIGlet font files will be stored in
FIGlet's default font directory.

=head1 OPTIONS

C<new>

=over

=item B<-D=E<gt>>I<boolean>

B<-D> switches to the German (ISO 646-DE) character set.
Turns I<[>, I<\> and I<]> into umlauted A, O and U, respectively.
I<{>, I<|> and I<}> turn into the respective lower case versions of these.
I<~> turns into s-z. B<-E> turns off B<-D> processing.
These options are deprecated, which means they probably
will not appear in the next version of B<Text::FIGlet::Font>.

=item B<-U>

Process input as Unicode (UTF-8).

=item B<-f=E<gt>>F<fontfile>

The font to load.

Defaults to F<standard>

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

=back

C<figify>

Returns a a string or list of lines, depending on context.

=over

=item B<-A=E<gt>>I<text>

The text to transmogrify.

=item B<-X=E<gt>>[LR]

These options control whether FIGlet prints left-to-right or right-to-left.
B<L> selects left-to-right printing. B<R> selects right-to-left printing.
The default is to use whatever is specified in the font file.

=item B<-x=E<gt>>[lrc]

These options handle the justification of B<Text::FIGlet::Font>
output. B<c> centers the output horizontally. B<l> makes the output
flush-left. B<r> makes it flush-right. The default sets the justification
according to whether left-to-right or right-to-left text is selected.
Left-to-right text will be flush-left, while right-to-left text will be
flush-right. (Left-to-rigt versus right-to-left text is controlled by B<-X>.)

=item B<-w=E<gt>>I<outputwidth>

The output width, output text is wrapped to this value by breaking the
input on whitspace where possible. There are two special width values

 -1 the text is not wrapped.
  1 the text is wrapped after very character.

Defaults to 80

=back

=head1 ENVIRONMENT

B<Text::FIGlet::Font> will make use of these environment variables if present

=over

=item FIGFONT

The default font to load.
If undefined the default is F<standard.flf>.
It should reside in the directory specified by FIGLIB.

=item FIGLIB

The default location of fonts.
If undefined the default is F</usr/games/lib/figlet>

=back

=head1 FILES

FIGlet font files are available at

  ftp://ftp.figlet.org/pub/figlet/

=head1 SEE ALSO

L<Text::FIGlet>, L<figlet(6)>

=head1 CAVEATS

=over

=item $/ is used to create the output string in scalar context

=item B<-m=>E<gt>'-0'

#XXX
Some fonts use 

=back

Consequently, make sure it is set appropriately i.e.;
 Don't mess with it, B<perl> sets it correctly for you.

=head1 AUTHOR

Jerrad Pierce

                **                                    />>
     _         //                         _  _  _    / >>>
    (_)         **  ,adPPYba,  >< ><<<  _(_)(_)(_)  /   >>>
    | |        /** a8P_____88   ><<    (_)         >>    >>>
    | |  |~~\  /** 8PP"""""""   ><<    (_)         >>>>>>>>
   _/ |  |__/  /** "8b,   ,aa   ><<    (_)_  _  _  >>>>>>> @cpan.org
  |__/   |     /**  `"Ybbd8"'  ><<<      (_)(_)(_) >>  
               //                                  >>>>    /
                                                    >>>>>>/
                                                     >>>>>

=cut
