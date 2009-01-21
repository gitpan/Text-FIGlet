exit 0 unless $] < 5.006;

sub eq_or_diff{
  print( ($_[0] eq $_[1] ? '': 'not '), "ok $_[2]\n");
}

sub ok{
  print( ($_[0] ? '': 'not '), "ok $_[1]\n");
}

foreach my $file ( glob("TEST/*.t") ){
  my $test;

  open(TEST, $file) || do{ warn("#Something wrong with $file: $!\n"); next };
  while(<TEST>){
    s/\\x\{(.+?)\}/\@{[Text::FIGlet::UTF8chr(0x\1)]}/g;
    s%t/%TEST/%;
    $test .= $_ unless /BEGIN|use\s+Test/;
  }

  eval $test;
  warn "#$file: $@\n" if $@;
}
