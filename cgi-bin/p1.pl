#!C:/Perl/bin/perl

# Where is the upload file going?
my $Upload_Dir = '/tmp';

$|++;

use strict;
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use CGI::Ajax;

my $s = 0;

my $pjx = new CGI::Ajax('check_status' => \&check_status);
my $q = CGI->new(\&hook);

sub hook {
  #my ($filename, $buffer, $bytes_read, $data) = @_;
  #my  $per = 10;

  $s += 10;

  #open (COUNTER, ">" . $Upload_Dir . '/' . $filename . '-meta.txt');
  #print COUNTER $per;
  #close(COUNTER);

  #$q->param(-name=>'counter', -value=>$s);

  return;
}

my $init_rand_string = 0;

if(!$q->param('process')){
   $init_rand_string = generate_rand_string();
}

my $d = <<EOF

<html>
<head></head>
<body>
<form name="default_form" enctype="multipart/form-data" method="post">
<p>
  <input type="file" name="uploadedfile" />
</p>
<input type="hidden" name="counter" value="0" />
<input type="hidden" name="yes_upload" value="1" />
<input type="hidden" name="process" value="1" />
<input type="hidden" name="rand_string" id="rand_string" value="$init_rand_string" />
<p>
  <input type="submit" value="upload." />
</p>
</form>
<script language="Javascript">
  setInterval("check_status(['check_upload__1', 'rand_string', 'uploadedfile'], ['statusbar']);",'1000');
</script>
<div id="statusbar"></div>
</body>
</html>

EOF
;

my $outfile = $Upload_Dir . '/' . $q->param('rand_string') . '-' . $q->param('uploadedfile');
my $p = <<EOF

<html>
<head></head>
<body>
<h1>Done!:</h1><hr />
</body>
</html>

EOF
;

main();

sub main {
  if($q->param('process')) {
    if($q->param('yes_upload')) {
      for (1..10) {
         upload_that_file($q);
      }
    }
    print $q->header();
    print $p;

    dump_meta_file();

  } else {
    print $pjx->build_html($q, $d);
  }
}

sub upload_that_file {
  my $q = shift;
  #my $fh = $q->upload('uploadedfile');
  #my $filename = $q->param('uploadedfile');

  sleep 1;
  return;
}

sub check_status {
  my $s = $q->param('counter') || 0;

  my $small = 500 - ($s * 5);
  my $big = $s * 5;

  my $r =
    '<h1>' . $s . '%</h1>'.
    '<div style="width:' . $big   . 'px;height:25px;background-color:#6f0;float:left"></div>'.
    '<div style="width:' . $small . 'px;height:25px;background-color:f33;float:left"></div>';
  return $r;
}

sub dump_meta_file {
  return;
}

sub generate_rand_string {
  return 'xxx';
}

exit(0);
