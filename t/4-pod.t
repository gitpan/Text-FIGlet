eval "use Test::More";
unless( $@ ){
  eval "use Test::Pod 1.00";
  plan(skip_all => "Test::Pod 1.00 required for testing POD: $@") if $@;
  all_pod_files_ok();
}
else{
  print "1..0\n";
}
