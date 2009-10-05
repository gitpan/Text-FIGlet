BEGIN{ exit -1 if $] < 5.006; eval "use Test::Simple tests => 4; use Test::Differences"; $|=1}
use Text::FIGlet;


#1 Known mix, top
$font = Text::FIGlet->new(-d=>'share', -v=>"top",
			  -f=>{undef=>'mini', standard=>qr/[A-Z]/});
#-f{undef=>'future', emboss=>qr/[A-Z]/} is nicer, but requires ZIP

my $pinky = <<'PINKY';
 _____             
|_   _|._  _  _  | 
  | |  |  (_) /_ o 
  | |              
  |_|              
                   
PINKY
eq_or_diff(~~$font->figify(-A=>'Troz!'), $pinky, 'Known mix, top');


#2 Known mix, default center
$font = Text::FIGlet->new(-d=>'share',
			  -f=>{undef=>'mini', standard=>qr/[A-Z]/});
#-f{undef=>'future', emboss=>qr/[A-Z]/} is nicer, but requires ZIP

my $brain = <<'BRAIN';
 _____             
|_   _|            
  | |  ._  _  _  | 
  | |  |  (_) /_ o 
  |_|              
                   
BRAIN
eq_or_diff(~~$font->figify(-A=>'Troz!'), $brain, 'Known mix, default center');


#3 Known mix, baseline
$font = Text::FIGlet->new(-d=>'share', -v=>"baseline",
			  -f=>{undef=>'future', standard=>qr/[A-Z]/});
my $cheezes = <<'CHEEZES';
 _____           
|_   _|          
  | |  ┏━┓┏━┓╺━┓╻
  | |  ┣┳┛┃ ┃┏━┛╹
  |_|  ╹┗╸┗━┛┗━╸╹
                 
CHEEZES
eq_or_diff(~~$font->figify(-A=>'Troz!'), $cheezes, 'Known mix, baseline');


#4 Known mix, baseline
$font = Text::FIGlet->new(-d=>'share', -v=>"bottom",
			  -f=>{undef=>'future', standard=>qr/[A-Z]/});
my $plots = <<'PLOTS';
 _____           
|_   _|          
  | |            
  | |  ┏━┓┏━┓╺━┓╻
  |_|  ┣┳┛┃ ┃┏━┛╹
       ╹┗╸┗━┛┗━╸╹
PLOTS
eq_or_diff(~~$font->figify(-A=>'Troz!'), $plots, 'Known mix, bottom');
#$a=$font->figify(-A=>'Troz!');
#$_ =~ y/ /./ foreach ($a, $plots);
#print STDERR foreach ($a, $plots);
