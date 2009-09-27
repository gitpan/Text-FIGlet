package Text::FIGlet::Font;
require 5;
use strict;
use vars qw($REwhite $VERSION);
use Carp qw(cluck confess);
use Symbol; #5.005 support
use Text::Wrap;
$VERSION = 2.11;

sub new{
  shift();
  my $self = {_maxLen=>0, -U=>-1, @_};
  $self->{-f} ||= $ENV{FIGFONT} || 'standard';
  $self->{-d} ||= $ENV{FIGLIB}  || '/usr/games/lib/figlet/';
  _load_font($self);
  bless($self);
}

sub _load_font{
  my $self = shift();
  my $font = $self->{_font} = [];
  my(@header, $header, $path, $ext);
  local($_);

#MAGIC minifig0
  $self->{'_file'} = Text::FIGlet::_canonical($self->{-d},
					      $self->{-f},
					      qr/\.[ft]lf/,
					      $^O =~ /MSWin32|DOS/i);
  $self->{_file} = (glob($self->{_file}.'.?lf'))[0] unless -e $self->{_file};


  #open(FLF, $self->{_file}) || confess("$!: $self->{_file}");
  $self->{_fh} = gensym;            #5.005 support
  eval "use IO::Uncompress::Unzip"; #XXX sniff for 'PK\003\004'instead?
  unless( $@ ){
      $self->{_fh} = eval{ IO::Uncompress::Unzip->new($self->{_file}) } ||
	  confess("No such file or directory: $self->{_file}");
  }
  else{
      open($self->{_fh}, '<'.$self->{_file}) || confess("$!: $self->{_file}");
      #$^W isn't mutable at runtime in 5.005, so we have to conditional eval
      #to avoid "Useless use of constant in void context"
      eval "binmode(\$fh, ':encoding(utf8)')" unless $] < 5.006;
  }
#MAGIC minifig1

  my $fh = $self->{_fh};  #5.005 support
  chomp($header = <$fh>); #5.005 hates readline & $self->{_fh} :-/
  confess("Invalid FIGlet 2/TOIlet font") unless $header =~ /^[ft]lf2/;

  #flf2ahardblank height up_ht maxlen smushmode cmt_count rtol
  @header = split(/\s+/, $header);
  $header[0] =~ s/^[ft]lf2.//;
  $header[0] = quotemeta($header[0]);
#  $header[0] = qr/@{[sprintf "\\%o", ord($header[0])]}/;
  $self->{_header} = \@header;

  unless( exists($self->{-m}) && defined($self->{-m}) && $self->{-m} ne '-2' ){
    $self->{-m} = $header[4];
  }

  #Discard comments
  <$fh> for 1 .. $header[5] || cluck("Unexpected end of font file") && last;

  #Get ASCII characters
  foreach my $i(32..126){
    &_load_char($self, $i) || last;
  }

  #German characters?
  unless( eof($fh) ){
    my %D =(91=>196, 92=>214, 93=>220, 123=>228, 124=>246, 125=>252, 126=>223);

    foreach my $k ( sort {$a <=> $b} keys %D ){
      &_load_char($self, $D{$k}) || last;
    }
    if( $self->{-D} ){
      $font->[$_] = $font->[$D{$_}] for keys %D;
      #removal is necessary to prevent 2nd reference to same figchar,
      #which would then become over-smushed; alas 5.005 can't delete arrays
      $#{$font} = 126; #undef($font->[$_]) for values %D;
    }
  }

  #ASCII bypass
  close($fh) unless $self->{-U};

  #Extended characters, with extra readline to get code
  until( eof($fh) ){
    $_ = <$fh> || cluck("Unexpected end of font file") && last;

    /^\s*$Text::FIGlet::RE{no}/;
    last unless $2;
    my $val = Text::FIGlet::_no($1, $2, $3, 1);

    #Bypass negative chars?
    if( $val > Text::FIGlet::PRIVb && $self->{-U} == -1 ){
	readline($fh) for 0..$self->{_header}->[1]-1;
    }
    else{
	#Clobber German chars
	$font->[$val] = '';
	&_load_char($self, $val) || last;
    }
  }
  close($fh);


  if( $self->{-m} eq '-0' ){
    my $pad;
    for(my $ord=0; $ord < scalar @{$font}; $ord++){
      next unless defined $font->[$ord];
#     foreach my $i (3..$header[1]+2){
      foreach my $i (-$header[1]..-1){
        #next unless exists($font->[$ord]->[2]); #55compat
        next unless defined($font->[$ord]->[2]);

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
      next unless defined $font->[$ord];
      foreach my $i (-$header[1]..-1){
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
      next unless defined $font->[$ord];
      foreach my $i (-$header[1]..-1){
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

  my $fh = $self->{_fh}; #5.005 support
  
  my $REtrail;
  foreach my $j (0..$self->{_header}->[1]-1){
    $line = $_ = <$fh> ||
      cluck("Unexpected end of font file") && return 0;
    #This is the end.... this is the end my friend
    unless( $REtrail ){
      /(.)\s*$/;
      $end = $1;
#XXX  $REtrail = qr/([ $self->{_header}->[0]]+)$end{1,2}\s*$/;
      $REtrail = qr/([ $self->{_header}->[0]]+)\Q$end$end\E?\s*$/;
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
    $length = $l if ($l = length($_)-1-(s/\Q$end\E+$/$end/mog)) > $length;
    $font->[$i] .= $line;
  }
  #XXX :-/ stop trying at 125 in case of map in ~ or extended....
  $self->{_maxLen} = $length if $i < 126 && $self->{_maxLen} < $length;

  #Ideally this would be /o but then all figchar's must have same EOL
  $font->[$i] =~ s/\Q$end\E|\015//g;
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
    $opts{-U} || &Encode::_utf8_off($opts{-A}) if $] >= 5.008;

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
					$opts{-U} ? Text::FIGlet::UTF8ord($1) : ord($1)
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
	push @lchars, ($opts{-U} ? Text::FIGlet::UTF8ord($1) : ord($1));
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
	}

	eval "use encoding  'utf-8'; use utf8;";
#	$self->{_header}->[0] = qr/@{[sprintf "\\%o", ord($self->{_header}->[0])]}/;

	#/o because we can't tr
	#warn "$line =~ s/$self->{_header}->[0]/ /og;\n";
	$line =~ s/$self->{_header}->[0]/ /og;
	
	
	#Do some more text formatting here... (smushing?)
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

    #Properly promote (back) to utf-8
    eval 'Encode::_utf8_on($_) foreach @buffer' unless $] < 5.006;

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

  print ~~$font->figify(-A=>"Hello World");

=head1 DESCRIPTION

Text::FIGlet::Font reproduces its input using large characters made up of
other characters; usually ASCII, but not necessarily. The output is similar
to that of many banner programs--although it is not oriented sideways--and
reminiscent of the sort of I<signatures> many people like to put at the end
of e-mail and UseNet messages.

Text::FIGlet::Font can print in a variety of fonts, both left-to-right and
right-to-left, with adjacent characters kerned and I<smushed> together in
various ways. FIGlet fonts are stored in separate files, which can be
identified by the suffix I<.flf>. Most FIGlet font files will be stored in
FIGlet's default font directory F</usr/games/lib/figlet>. Support for TOIlet
fonts I<*.tlf>, which are typically in the same location, has also been added.

This implementation is known to work with perl 5.005, 5.6 and 5.8,
with support for Unicode characters in each. See L</CAVEATS> for details.

=head1 OPTIONS

C<new>

=over

=item B<-D=E<gt>>I<boolean>

B<-D> switches to the German (ISO 646-DE) character set.
Turns I<[>, I<\> and I<]> into umlauted A, O and U, respectively.
I<{>, I<|> and I<}> turn into the respective lower case versions of these.
I<~> turns into s-z.

This option is deprecated, which means it may soon be removed from
B<Text::FIGlet::Font>. The modern way to achieve this effect is with
L<Text::FIGlet::Control>.

=item B<-U=E<gt>>I<boolean>

A true value, the default, is necessary to load Unicode font data;
regardless of your version of perl

B<Note that you must explicitly specify I<1> if you are mapping in negative
characters with a control file>. See L</CAVEATS> for more details.

=item B<-f=E<gt>>F<fontfile>

The font to load; defaults to F<standard>.

The fontfile may be zipped if L<IO::Uncompress::Unzip> is available.

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

=item B<-U=E<gt>>I<boolean>

Process input as Unicode (UTF-8).

B<Note that this applies regardless of your version of perl>,
and is necessary if you are mapping in negative characters
with a control file.

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

Consequently, make sure it is set appropriately i.e.;
Don't mess with it, B<perl> sets it correctly for you.

=item B<-m=>E<gt>'-0'

This mode is peculiar to Text::FIGlet, and as such, results will vary
amongst fonts.

=item Support for pre-5.6 perl

This codebase was originally developed to be compatible with 5.005.03,
and has recently been manually checked against 5.005.04. Unfortunately,
the default test suite makes use of code that is not compatable with
versions of perl prior to 5.6. F<test.pl> attempts to work around this
to provide some basic testing of functionality.

=back

=head2 Unicode

=over

=item Pre-5.8

Perl 5.6 Unicode support was notoriously sketchy. Best efforts have
been made to work around this, and things should work fine. If you
have problems, favor C<"\x{...}"> over C<chr>. See also L<Text::FIGlet/NOTES>

=item Pre-5.6

Text::FIGlet B<does> provide limited support for Unicode in perl 5.005.
It understands "literal Unicode characters" (UTF-8 sequences), and will
emit the correct output if the loaded font supports it. It does not
support negative character mapping at this time.
See also L<Text::FIGlet/NOTES>

=back

=head2 Memory

The standard font is 4Mb with no optimizations.

Listed below are increasingly severe means of reducing memory use.

=over

=item B<-U=E<gt>-1>

This loads Unicode fonts, but skips negative characters. It's the default.

The standard font is 68kb with this optimization.

=item B<-U=E<gt>0>

This only loads ASCII characters; plus the Deutsch characters if -D is true.

The standard font is 14kb with this optimization.

=back

=head1 BUGS

Inclusion of wide characters (UTF8) as glyph fragments,
as in many TOIlet fonts, may cause premature wrapping.
You should not see this I<if> your perl supports UTF-8 natively,
I<and> you do not have IO::Uncompress::Unzip installed for zip
font support; I'm not convinced it's worth sniffing to see
if the file's uncompressed if you do have the module installed.

A work-around is to pass a B<-w> 3 times the width needed;
an approximation, since the most likely Unicode characters
to be used in font are the block elements and line drawing
characters.

=head1 RESTRICTIONS

There is support for negative characters -1 through -65,536.

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
