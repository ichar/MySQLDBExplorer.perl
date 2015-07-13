#!C:/Perl/bin/perl

use strict;
use POSIX qw(strftime);
use Cwd;
use DBI;

my $IsDebug = 0;

my @body = (
  "Content-Type: text/html\n\n",
  "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n",
  "<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"ru\" xml:lang=\"ru\">\n\n",
  "<head>\n",
  "<title>SQL DB Query Loader</title>\n",
  "</head>\n\n",
  "<body>\n",
  "<script type=\"text/javascript\">\n",
  "<!--\n",
  "window.onload = window.parent.RefreshLoader;\n",
  "//-->\n",
  "</script>\n",
  "<br>\n",
  "<form id=\"loaderForm\" name=\"loaderForm\" action=\"/cgi-bin/loader.pl\" method=\"post\">\n",
  "<input name=\"provider\" type=\"hidden\" value=\"\">\n",
  "<input name=\"charset\" type=\"hidden\" value=\"\">\n",
  "<input name=\"nowrap\" type=\"hidden\" value=\"\">\n",
  "<input name=\"database\" type=\"hidden\" value=\"\">\n",
  "<input name=\"query\" type=\"hidden\" value=\"\">\n",
  "\n",
  "<div id=\"data\">\n"
);

print "$_" foreach @body;
#print cwd."\n";

require '_config.pl';
require '_defs.pl';
require '_lib.pl';
require '_query.pl';
require '_sql.pl';

# Get form params (GET/POST) ---------------------------------------------------
my %qs = &get_query();

if( $IsDebug == 1 ) {
  #print keys %qs || 'no query string';
  #print "\n";
  $qs{'provider'} = 'mssql';
  $qs{'database'} = 'Deshevle';
  $qs{'charset'}  = 'koi8r';
  $qs{'nowrap'}   = 'nowrap';
}

if( $IsDebug == 1 && ! $qs{'query'} ) {
  $qs{'query'} =
    "#comment\n".
    "select IDClass, ClLevel, ClParent, ClCode, ClName from _rClass;";
    #"select top 1000 IDClass, ClLevel, ClParent, ClCode, ClName into classes from Deshevle.dbo._rClass order by ClCode;";
    #"insert into x.aaa values(0,'рст');".
    #"<p>SELECT * FROM pc_Root WHERE RID IN (1,2,3);</p>".
    #"<p>SELECT RID, attrValue FROM pcSearchableText WHERE RID IN (1,2,3)</p>;";
    #"select * from indexes";
}
#
# Params -----------------------------------------------------------------------
#
my $provider = $qs{'provider'} || '';
my $nowrap   = $qs{'nowrap'}   || '';
#
# ------------------------------------------------------------------------------
#
# Connect to the database
my $dbh = &db_connect($qs{'provider'}, $qs{'database'}, $qs{'charset'});
#
# Get SQL query batch ----------------------------------------------------------
#
my @sql_query = split /;/, &plain_text(&txt2html($qs{'query'}), 1);
#
# ------------------------------------------------------------------------------
#
my @columns;            # Columns list
my @errors;             # Errors list

if( $IsDebug == 1 && scalar(@sql_query) > 0 ) {
  print "Number of SQL query: ".scalar(@sql_query)."<br>";
  print "\n$_;" foreach @sql_query;
  print "\n";
  #print join(";\n", @sql_query);
  #print "\n";
}

# Open Log handle
open my $LOG_HANDLE, '>>', '../htdocs/log/loader.log' or die;
#print $LOG_HANDLE (%qs ? "$qs{'database'}" : '')."\n";

# Run query and print recordset
while ( @sql_query and my ($sql, $type) = &check_sql_query( $provider, shift @sql_query ) ) {
  if( ! $sql or length($sql) < 10 ) {
    next;
  }
  print "<p><strong>".$sql."</strong></p>\n";
  my $now = strftime "%d.%m.%Y %H:%M", localtime;
  print $LOG_HANDLE "$now: $sql\n";

  if( $type == 1 || $type == 3 ) {
    $dbh->do( $sql );
    $dbh->commit() or die $dbh->errstr;
    next;
  }

  my $sth = $dbh->prepare( $sql );

  eval {
    $sth->execute();
  };

  if ($@) {
    push @errors, $@;
    next;
  }

  my $table = '';
  my $n = 0;
  while ( my $row = $sth->fetch() ) {
    if( !$n ) {
      $table = "<table style=\"BORDER-COLLAPSE: collapse\" cellspacing=\"0\" cellpadding=\"0\" border=\"1\">\n";
      $table .= "<tr>";
      $table .= "<th class=\"cell\">$_</th>" foreach @{$sth->{NAME}};
      $table .= "</tr>\n";
    }
    $table .= "<tr>";
    foreach (@$row) {
      $_ = '&nbsp;' unless defined;
      $table .= "<td class=\"cell\" $nowrap>$_</td>";
    }
    $table .= "</tr>\n";
    $n++;
  }
  if( $n > 0 ) {
    $table .= "</table>\n";
    print $table;
    print "\n<br><strong>Total selected: $n rows.</strong>\n";
  }

  $sth->finish();
}

# Close Log handle
close $LOG_HANDLE or die;

# Disconnect from the database
&db_close($dbh);

my $err_div = "<br>\n";

if( @errors ) {
  $err_div .= "<div class=\"errors\" id=\"errors\">\n";
  foreach my $x (@errors) {
    $err_div .= "<p>".&txt2html($x)."</p>\n";
  }
  $err_div .= "</div>\n"
}

@body = (
  "</div>\n",
  "</form>\n",
  $err_div,
  "</body>\n",
  "</html>"
);

print "$_" foreach @body;

exit(0);