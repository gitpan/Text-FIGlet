package Text::FIGlet;
require 5;
use constant PRIVb => 0xF0000;
use constant PRIVe => 0xFFFFD;
use strict;
use vars qw'$VERSION %RE';
use Carp qw(carp croak);
$VERSION = 2.00;

use Text::FIGlet::Font;
use Text::FIGlet::Control;

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
__END__
1;
=pod

=head1 NAME

Text::FIGlet - a perl module to provide FIGlet abilities, akin to banner

=head1 SYNOPSIS

 my $font = Text::FIGlet-E<gt>new(-f=>"doh");
 $font->figify(-A=>"Hello World");

=head1 DESCRIPTION

FIGlet reproduces its input using large characters made up of
ordinary screen characters. FIGlet output is generally
reminiscent of the sort of I<signatures> many people like
to put at the end of e-mail and UseNet messages. It is
also reminiscent of the output of some banner programs,
although it is oriented normally, not sideways.

FIGlet can print in a variety of fonts, both left-to-right
and right-to-left, with adjacent characters kerned and
I<smushed> together in various ways. FIGlet fonts are
stored in separate files, which can be identified by the
suffix I<.flf>. Most FIGlet font files will be stored in
FIGlet's default font directory.

FIGlet can also use control files, which tell it to
map certain input characters to certain other characters,
similar to the Unix tr command. Control files can be
identified by the suffix I<.flc>. Most FIGlet control
files will be stored in FIGlet's default font directory.

=head1 OPTIONS

C<new>

=over

=item B<-C=E<gt>>F<controlfile>

Creates a control object.
L<Text::File::Control> for control object specific options to new,
and how to use the object.

=item B<-f=E<gt>>F<fontfile>

Creates a font object.
L<Text::File::Font> for font object specific options to new,
and how to use the object.

=item B<-d=E<gt>>F<fontdir>

Whence to load files.

Defaults to F</usr/games/lib/figlet>

=back

C<new> with no options will create a font object using the default font.

=head1 EXAMPLES

C<perl -MText::FIGlet -e
'print Text::FIGlet-E<gt>new()-E<gt>figify(-A=E<gt>"Hello World")'>

To generate headings for webserver directory listings,
for that warm and fuzzy BBS feeling.

Text based clocks or counters at the bottom of web pages.

Provide e-mail addresses etc. in a difficult to harvest manner, L<AUTHOR>.

=head1 ENVIRONMENT

B<Text::FIGlet> will make use of these environment variables if present

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

FIGlet font files and control files are available at

  ftp://ftp.figlet.org/pub/figlet/
 
=head1 SEE ALSO

L<Acme::Curses::Marquee::Extensions>

L<figlet(6)>, L<http://www.figlet.org|http://www.figlet.org>

L<banner(6)>, L<Text::Banner>

=head1 CAVEATS

=over

=item Negative character codes

There is limited support for negative character codes,
at this time only characters -2 through -65_535 are supported.

=back

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

=head1 LICENSE

=over

=item * Thou shalt not claim ownership of unmodified materials.

=item * Thou shalt not claim whole ownership of modified materials.

=item * Thou shalt grant the indemnity of the provider of materials.

=item * Thou shalt use and dispense freely without other restrictions.

=back

Or if you truly insist, you may use and distribute this under ther terms
of Perl itself (GPL and/or Artistic License).

=cut
