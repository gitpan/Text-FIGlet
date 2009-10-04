package Text::FIGlet::Ransom;
require 5;
use strict;
use vars qw/$VERSION @ISA/;
use Carp 'croak';
use List::Util qw/max/;
use Text::FIGlet;
$VERSION = 2.14;
@ISA = 'Text::FIGlet::Font';

sub new{
  shift();
  my $self = {-U=>0, @_};
  my @fonts;


  croak "Invalid font list" unless scalar(@{$self->{-f}}) > 1;

  #Load the fonts
  foreach my $font ( @{$self->{-f}} ){
      push(@fonts, Text::FIGlet::Font->new(%$self, -f=>$font));
  }

  #Synthesize a header
  #Hardblank
  $self->{_header}->[0] = "\177";
  #Height
  $self->{_header}->[1] = max( map {$_->{_header}->[1]} @fonts );
  #up_ht = XXX unused, but affects valign?
  $self->{_header}->[3] = $self->{_maxLen} = max( map {$_->{_maxLen}} @fonts );
  #Smush
  $self->{_header}->[4] = 0;
  #cmt_count = dump @_
  #R2L
  $self->{_header}->[6] = 0;

  #Assemble the body
  #XXX 32
  for(my $i=32; $i<127; $i++ ){
    my $R = rand(scalar(@fonts));
    my $c = $fonts[$R]->{_font}->[$i];

    #Vertical-alignment & padding
    #XXX
    if( $fonts[$R]->{_header}->[1] < $self->{_header}->[1] ){
      push(@$c, ' 'x($c->[0]-1)) for 1..
	$self->{_header}->[1] - $fonts[$R]->{_header}->[1];
    }

    #Common hardblank
    my $iHard=$fonts[$R]->{_header}->[0];
    for(my $j=0; $j<$self->{_header}->[1]; $j++){
      $c->[$j+3]=~ s/$iHard/\177/g;
    }

    $self->{_font}->[$i] = $c;
  }

  bless($self);
}

1;
__END__
=pod

=head1 NAME

Text::FIGlet::Ransom - composite font support

=head1 SYNOPSIS

  use Text::FIGlet;

  my $ransom = Text::FIGlet->new(-f=>[ qw/big block banner/ ]);

  print $ransom->figify("Hi mom");

             _
  _|    _|  (_) #    #        #    #
  _|    _|   _  ##  ##   ___  ##  ##
  _|_|_|_|  | | # ## #  / _ \ # ## #
  _|    _|  | | #    # | (_) |#    #
  _|    _|  |_| #    #  \___/ #    #
                #    #        #    #

=head1 DESCRIPTION

This class creates a new FIGlet font using glyphs from user-specified fonts.
Output from the resulting hybrid font is suitable for basic textual CAPTCHA,
but also has artistic merit. As the output is automatically generated though,
some manual adjustment may be necessary; particularly since B<Text::FIGlet>
still does not support smushing.

=head2 TODO

=over

=item Treat 0x20 specially?

=item Instantiation via B<Text::FIGlet>

Font if -f is a string, Ransom if an array/hash ref

=back

=head1 OPTIONS

=head2 C<new>

Loads the specified set of fonts, and assembles glyphs from them to create
the new font.

Except where otherwise noted below, options are inherited from
L<Text::FIGlet::Font>.

=over

=item B<-f=E<gt>>I<\@fonts> | I<\%fonts>

The array reference forms accepts a reference to a list of fonts to use
in constructing the new font. When the object is instantiated B<Ransom>
iterates over all of the codepoints, randomly copying the glyph for that
index from one of the specified fonts.

The hash form is not yet implemented, but will accept a hashref with a
font as key, and a regular expression as values which matches the glyphs
from that font to be used in the ransomed font. A default font to pull
glyphs from is specified with a I<key> of C<undef> and the font as the I<value>.

  Text::FIGlet::Ransom->new(-f=>{slant=E<gt>qr/a-z/, undef=>'./Doh.flf'})

In the text above, I<font> means any value accepted by the B<-f> parameter
of C<Text::FIGlet::new>.

=item B<-U=E<gt>>I<boolean>

A true value is necessary to load Unicode font data,
regardless of your version of perl. B<The default is false>.

B<Note that you must explicitly specify I<1> if you are mapping in negative
characters with a control file>. Otherwise, I<-1> is more appropriate.
See L<Text::FIGlet::Font/CAVEATS> for more details.

=item B<-v>=E<gt>'I<vertical-align>'

Not yet implemented.

Because fonts vary in size, it is necessary to provide vertical padding
around smaller glyphs, and this option controls how the padding is added.
The default is to S<center> the glyphs.

=over

=item I<top>

Align the tops of the glyphs

=item I<center>

Align the center of the glyphs

=item I<baseline>

Align the the base of the glyphs i.e; align characters such as "q" and "p"
as if they had no descenders.

=item I<bottom>

Align the bottom of the glyphs

=item I<random>

Randomly select an alignment for each character when assembling the font.

=back

=back

=head2 C<figify>

Inherited from L<Text::FIGlet::Font>.

=head2 C<freeze>

Not yet implemented.

Allow for the preservation of the current (random) font for reuse,
and to avoid the performance penalty incurred upon B<Random>-ization.

=head1 ENVIRONMENT

B<Text::FIGlet::Ransom>
will make use of these environment variables if present

=over

=item FIGLIB

The default location of fonts.
If undefined the default is F</usr/games/lib/figlet>

=head1 CAVEATS

Cannot (yet) ransom with TOIlet fonts.

=head1 SEE ALSO

L<Text::FIGlet::Font>, L<Text::FIGlet>, L<figlet(6)>

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
