#!C:/Perl/bin/perl

use strict;
use CGI;      # or any other CGI:: form handler/decoder
use CGI::Ajax;

my $cgi = new CGI;
my $pjx = new CGI::Ajax( 'exported_func' => \&perl_func );

my $db = 'xxxxxx';
my $counter = 0;

sub perl_func {
  my ($input, $s) = @_;
  # do something with $input
  $s = 0 unless $s < 100;
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
  sleep 0.1;
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
    var OK = document.getElementById('OK');
    if( counter < 100 ) {
      if( counter == 1 ) OK.innerHTML = '';
      exported_func( ['db','counter','NO_CACHE'], [js_process_func] );
    } else
    OK.innerHTML = '<h2>Done!</h2>';
}
</script>
<h2>Example of simple *ProgressBar* implementation</h2>
<br>
Real counter: <input type="text" name="counter" id="counter" size="3" value="0" style="text-align:center">
Some Perl item value: <input type="text" name="db" id="db" size="5" value="">
<br><br>
 Click this button:&nbsp
<input type="button" name="run" id="run" value="  Start  " onclick="exported_func( ['db','counter'], [js_process_func] );">
<br>
<br>
<div id="resultdiv"></div>
<br>
<div id="OK"></div>

</BODY>
</HTML>

EOHTML
  return $html;
}

exit(0);
