package Text::FIGlet;
$VERSION = '1.02';
use Carp qw(carp croak);
use File::Spec;
use strict;

sub new{
    shift();
    my $self = {@_};

    $self->{-f} ||= $ENV{FIGFONT} || 'standard';
    $self->{-d} ||= $ENV{FIGLIB}  || '/usr/games/lib/figlet/';
    #translate dir seperator in FIGLIB
    $self->{_font} = _load_font($self);
    bless($self);
    return $self;
}

sub _load_font($) {
    my $self = shift();
    my(@header, $header, %font, $font);
    local $_;

    $font = File::Spec->catfile($self->{-d}, $self->{-f});
    open(FLF, $font) || open(FLF, "$font.flf") || croak("$!: $font");
    chomp($header = <FLF>);
    croak("Invalid figlet 2 font") unless $header =~ /^flf2/;

    #flf2ahardblank height up_ht maxlen smushmode cmt_count rtol
    @header = split(/\s+/, $header);
    $header[0] =~ s/^flf2.//;
    $header[0] = quotemeta($header[0]);
    $self->{_header} = \@header;

    #Discard comments
    for(my $i=0; $i<$header[5]; $i++){
        <FLF>;
    }

    #Get ASCII characters
    for(my $i=32; $i<127; $i++){
	_load_char(\%font, \@header, $i);
    }

    #German characters?
    #-D
    #for(91,92,93,123,124,125,126){
    #_load_char(\%font, \@header, $i);
    #}

    #Extended characters, read extra line to get code
    #until( eof() ){
    #<FLF>
    #/^(\d+)/
    #_load_char(\%font, \@header, $1);
    #}

    return \%font;
}

sub _load_char($$$){
    my($font, $header, $i) = @_;

    my $length;
    for(my $j=0; $j<$header->[1]; $j++){
	local $_ = <FLF>;
	$font->{$i} .= $_;
	$length = $length > length($_) ? $length : length($_);
# XXX Bail if eof() ?!
	}
    $font->{$i} =~ /(.){2}$/;
    $font->{$i} =~ s/$1|\015//g;
#    #This will move to figify() once it supports kerning and smushing?
    $font->{$i} =~ s/$header->[0]/ /g;
    $font->{$i} = [$length-3, split($/, $font->{$i})];
}


sub figify{
    my $self = shift();
    my %opts = @_;
    my($buffer, @text);
    local $_;

    $opts{-w} ||= 80;

    #Do text formatting here...
    if( $opts{-w} == 1 ){
	@text = split(//, $opts{-A});
    }
    else{
	@text = split($/, $opts{-A});
    }
    if( $opts{-w} > 1 ){
	foreach my $line( @text ){
	    my $length;
	    my @lchars = map(ord($_), split('', $line));
	    $buffer = '';
	    foreach my $lchar (@lchars){
		$length += $self->{_font}->{$lchar}->[0];
		if( $length > $opts{-w} ){
		    $length = $self->{_font}->{$lchar}->[0];
		    $buffer .= $/ . chr($lchar);
		}
		else{
		    $buffer .= chr($lchar);
		}
	    }
	    $line = $buffer;
	}
	$buffer = '';
	@text = split($/, join($/, @text));
    }

    foreach( @text ){
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
    return $buffer;
}
1;
__END__
=pod

=head1 NAME

Text::FIGlet - a perl module to provide FIGlet abilities, akin to banner

=head1 SYNOPSIS

 my $font = Text::FIGlet-E<gt>new(-f=>"doh");
 $font->figify(-A=>"Hello World");

=head1 DESCRIPTION

C<new>

=over

=item B<d>

Whence to load the font.

Defaults to F</usr/games/lib/figlet.dir>

=item B<f>

The font to load.

Defaults to F<standard>

=back

C<figify>

=over

=item B<A>

The text to transmogrify.

=item B<w>

The output width, output text is wrapped to this value by breaking the
input on whitspace where possible. There are two special width values

 -1 the text is not wrapped.
  1 the text is wrapped after very character.

NOTE: This currently broken, it wraps to width
but breaks on the nearest input character,
not necessarily whitespace.

Defaults to 80

=back


=head1 EXAMPLES

C<perl -MText::FIGlet -e
'print Text::FIGlet-E<gt>new()-E<gt>figify(-A=E<gt>"Hello World")'>

=head1 ENVIRONMENT

Text::FIGlet will make use of these environet variables if present

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

L<figlet>

=head1 CAVEATS

=over

=item $/ is used to 

 split incoming text into seperate lines.
 item create the output string
 item parse the font file

=back

Consequently, make sure it is set appropriately i.e.;
 Don't mess with it, B<perl> sets it correctly for you.

=head1 AUTHOR

Jerrad Pierce <belg4mit@mit.edu>/<webmaster@pthbb.rg>

=cut
