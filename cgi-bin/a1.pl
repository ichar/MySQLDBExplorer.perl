#!C:/Perl/bin/perl

use strict;
use CGI;      # or any other CGI:: form handler/decoder
use CGI::Ajax;

my $cgi = new CGI;
my $pjx = new CGI::Ajax( 'exported_func' => \&perl_func );

sub perl_func {
  my $input = shift;
  # do something with $input
  my $s = length($input);
  $s = 100 unless $s < 100;
  my $bar_width = $s * 3;
  my @body = (
  "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n",
  "<tr>\n",
  "  <td width=\"300px\" style=\"padding: 1px 1px 1px 1px;border:1px solid #8080FF;\" nowrap>\n",
  "    <table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n",
  "    <tr>\n",
  "      <td id=\"bar\" bgcolor=\"blue\"><img src=\"/images/spacer.gif\" height=\"10\" width=\"".$bar_width."\"></td>\n",
  #($s > 0 ?
  #"      <td id=\"bar\" bgcolor=\"blue\">".'&nbsp;' x $s."</td>\n" :
  #"      <td id=\"bar\" bgcolor=\"white\">&nbsp;</td>\n"
  #),
  "    </tr>\n",
  "    </table>\n",
  "  </td>\n",
  "  <td style=\"padding-left:3px;\"><span><font size=\"-2\">".$s."%</font></span></td>\n",
  "</table>\n",
  );
  return( join '', @body );
}

print $pjx->build_html($cgi, \&Show_HTML);

sub Show_HTML {
  my $html =
<<EOHTML;

<HTML>
<BODY>
<br>
 Enter something:&nbsp;
<input type="text" name="val1" id="val1" onKeyUp="exported_func( ['val1'], ['resultdiv'] );">
<br>
<br>
<div id="resultdiv"></div>

</BODY>
</HTML>

EOHTML
  return $html;
}

exit(0);