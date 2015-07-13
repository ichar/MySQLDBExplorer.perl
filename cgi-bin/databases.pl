#!C:/Perl/bin/perl

use strict;
use DBI;

my $IsDebug = 0;

my @body = (
  "Content-Type: text/html\n\n",
  "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n",
  "<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"ru\" xml:lang=\"ru\">\n\n",
  "<head>\n",
  "<title>SQL DB Query Databases</title>\n",
  "</head>\n\n",
  "<body>\n",
  "<script type=\"text/javascript\">\n",
  "<!--\n",
  "window.onload = window.parent.RefreshDatabases;\n",
  "//-->\n",
  "</script>\n",
  "<br>\n",
  "<form id=\"databasesForm\" name=\"databasesForm\" action=\"/cgi-bin/databases.pl\" method=\"post\">\n",
  "<input name=\"provider\" type=\"hidden\" value=\"\">\n",
  "<input name=\"rows_counter\" type=\"hidden\" value=\"\">\n",
  "\n",
  "<div id=\"data\">\n"
);

print "$_" foreach @body;

require '_config.pl';
require '_defs.pl';
require '_lib.pl';
require '_query.pl';
require '_sql.pl';

# Get form params (GET/POST) ---------------------------------------------------
my %qs = &get_query();
#
# Params -----------------------------------------------------------------------
#
my $provider     = $qs{'provider'}     || '';
my $rows_counter = $qs{'rows_counter'} || 0;
#
# ------------------------------------------------------------------------------
#
if( $IsDebug == 1 ) {
  $provider = 'mssql';
  $rows_counter = 1;
}

# Log handle
#open my $LOG_HANDLE, '>>', '../htdocs/log/loader.log' or die;
#print $LOG_HANDLE (%qs ? "$qs{'database'}" : '...')."\n";
#close $LOG_HANDLE or die;

# Connect to the database
my $dbh = &db_connect($provider);

my $std;
my @databases;
my $schema = &q_defs($provider, 'schema');
my $qs = &q_defs($provider, 'show databases');

# Get available databases info
$std = $dbh->prepare( $qs );
$std->execute() or die;
@databases = &get_tuple( $std );

@body = ();

if( scalar @databases ) {
  push @body,
    "<table id=\"databases\" cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n";
}

foreach my $x ( sort @databases ) {
  push @body,
    "<tr>\n".
    "  <td><input type=\"radio\" id=\"i_".$x."\" name=\"selected_database\" value=\"".$x."\" onclick=\"javascript:setDatabase(this.value);\"></td>\n".
    "  <td style=\"padding-right:3px;\" nowrap><label id=\"l_".$x."\" for=\"i_".$x."\">".$x."</label><br>\n".
    "</tr>\n".
    "<tr>\n".
    "  <td></td>\n".
    "  <td nowrap id=\"".$x."\" style=\"display:none;padding: 3px 3px 3px 0;\">\n";

  # Get database tables info
  my $stt;
  my @tables;

  if( $provider eq 'mssql' ) {
    $stt = $dbh->prepare( "select * from ".$x.$schema."sysobjects where xtype='U' order by name" );
    $stt->execute() or die;
    @tables = &get_tuple( $stt );
  } else {
    $stt = $dbh->prepare( "SHOW TABLES FROM ".$x );
    $stt->execute() or die;
    @tables = &get_tuple( $stt );
  }

  my $rows = '';

  foreach my $y ( sort @tables ) {
    if( $rows_counter ) {
      $rows = ' <span class=counter>('.&execSelectCount( $dbh, $x.$schema.$y ).')</span>';
    }

    push @body, "    ".
      "<span class=\"oi\" id=\"".$x."_".$y.
      "\" onclick=\"javascript:addSelect(this, '".$x."','".$schema."','".$y."')\">".$y.$rows.
      "</span><br>\n";
  }

  push @body,
    "  </td>\n".
    "</tr>\n";

  $stt->finish();
}

$std->finish();

if( @body ) {
  push @body,
    "</table>\n";
}

print "$_" foreach @body;

# Disconnect from the database
&db_close($dbh);

@body = (
  "</div>\n",
  "</form>\n",
  "</body>\n",
  "</html>"
);

print "$_" foreach @body;

exit(0);