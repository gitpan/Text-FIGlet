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
    _load_font($self);
    bless($self);
    return $self;
}

sub _load_font($) {
    my $self = shift();
    my(@header, $header, $font);
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

    if( $self->{-F} ){
	my $len;
	foreach my $ord ( keys %{$self->{_font}} ){
	    for(my $i=1; $i<=$self->{_header}->[1]; $i++ ){
		$len = length($self->{_font}->{$ord}->[$i]);
		$self->{_font}->{$ord}->[$i] =
		    " " x int(($self->{_maxlen}-$len)/2) .
			$self->{_font}->{$ord}->[$i] .
			    " " x ($len-int(($self->{_maxlen}-$len)/2));
	    }
	    $self->{_font}->{$ord}->[0] = $self->{_maxlen};
	}
    }
}

sub _load_char($$$){
    my($self, $i) = @_;

    my $length;
    for(my $j=0; $j<$self->{_header}->[1]; $j++){
	local $_ = <FLF> || carp("Unexpected end of font file") && return 0;
	$self->{_font}->{$i} .= $_;
	$length = $length > length($_) ? $length : length($_);
	if( $self->{-F} ){
	    $self->{_maxlen} = $length > $self->{_maxlen} ?
		$length : $self->{_maxlen};
	}
    }
    $self->{_font}->{$i} =~ /(.){2}$/;
    $self->{_font}->{$i} =~ s/$1|\015//g;
#    #This will move to figify() once it supports smushing?
    $self->{_font}->{$i} =~ s/$self->{_header}->[0]/ /g;
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

=item B<-D=E<gt>>I<boolean>

If true, switches  to  the German (ISO 646-DE) character
set.  Turns `[', `\' and `]' into umlauted A, O and
U,  respectively.   `{',  `|' and `}' turn into the
respective lower case versions of these.  `~' turns
into  s-z. Assumin, of course, that the font author
included these characters. This option is deprecated, which means it
may not appear in upcoming versions of FIGlet.

=item B<-F=E<gt>>I<boolean>

This will pad each character in the font such that they are all
a consistent width. The padding is done such that the character
is centered in it's "cell", and any odd padding is the trailing edge.

NOTE: This should probably be considered experimental

=item B<-d=E<gt>>F<fontdir>

Whence to load the font.

Defaults to F</usr/games/lib/figlet.dir>

=item B<-f=E<gt>>F<fontfile>

The font to load.

Defaults to F<standard>

=back

C<figify>

=over

=item B<-A=E<gt>>I<text>

The text to transmogrify.

=item B<-w=E<gt>>I<outputwidth>

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

Text::FIGlet will make use of these environment variables if present

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

Jerrad Pierce <jpierce@cpan.org>/<webmaster@pthbb.rg>

=cut
