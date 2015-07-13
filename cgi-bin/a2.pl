#!C:/Perl/bin/perl

use strict;
use CGI;      # or any other CGI:: form handler/decoder
use CGI::Ajax;

my $cgi = new CGI;
my $pjx = new CGI::Ajax( 'exported_func' => \&perl_func );

my $db = 'xxx';
my $counter = 0;

sub perl_func {
  my ($input, $s) = @_;
  # do something with $input
  #my $s = length($input);
  $s = int($s) + 1;
  $s = 100 unless $s < 100;
  my $bar_width = $s * 3;
  my @body = (
  "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n",
  "<tr>\n",
  "  <td width=\"300px\" style=\"padding: 1px 1px 1px 1px;border:1px solid #8080FF;\" nowrap>\n",
  "    <table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n",
  "    <tr>\n",
  "      <td id=\"bar\" bgcolor=\"blue\"><img src=\"/images/spacer.gif\" height=\"10\" width=\"".$bar_width."\"></td>\n",
  "    </tr>\n",
  "    </table>\n",
  "  </td>\n",
  "  <td style=\"padding-left:3px;\"><span><font size=\"-2\">".$s."%</font></span></td>\n",
  "</table>\n",
  );
  $counter = $s;
  return ( join('', @body), $s, $db );
}

print $pjx->build_html($cgi, \&Show_HTML);

sub Show_HTML {
  my $html =
<<EOHTML;

<HTML>
<BODY>
<script language="JavaScript">
var counter=0;

function js_process_func() {
    var input1 = arguments[0];
    counter = parseInt(arguments[1]);
    var db = arguments[2]
    document.getElementById('resultdiv').innerHTML = input1;
    document.getElementById('counter').value = counter;
    document.getElementById('db').value = db;
}
</script>
<br>
<input type="text" name="counter" id="counter" size="3" value="0">
<input type="text" name="db" id="db" size="5" value="">
<br><br>
 Enter something:&nbsp;
<input type="text" name="val1" id="val1" onkeyup="exported_func( ['val1','counter'], [js_process_func] );">
<br>
<br>
<div id="resultdiv"></div>

</BODY>
</HTML>

EOHTML
  return $html;
}

exit(0);
