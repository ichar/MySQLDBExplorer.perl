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
  "<title>SQL DB Exporter</title>\n",
  "</head>\n\n",
  "<body>\n",
  "<script type=\"text/javascript\">\n",
  "<!--\n",
  "window.onload = window.parent.RefreshExporter;\n",
  "//-->\n",
  "</script>\n",
  "<br>\n",
  "<form id=\"exporterForm\" name=\"exporterForm\" action=\"/cgi-bin/exporter.pl\" method=\"post\">\n",
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
# DEBUG ------------------------------------------------------------------------
#
if( $IsDebug == 1 ) {
  #print keys %qs || 'no query string';
  #print "\n";
  $qs{'provider'}    = 'mssql';
  $qs{'database'}    = 'Deshevle';
  $qs{'charset'}     = 'cp1251';
  $qs{'query'}       =
  #    'select top 10 IDClass as ID, ClCode as code, ClName as title, IsPdNode, RD into classes from Deshevle.dbo._rClass order by ClCode;<BR>';
  #    'select * into attrs from Deshevle.dbo._rChr;<BR>';
  #    'select * into classes from _rClass order by ClCode;';
  #    "####comment string\n".
  #    "select\n".
  #    "IDClass as ID, ClLevel as level, ClParent as parent, ClCode as code, ClName as title, IsForPublish as published, RD\n".
  #    "into classes\n".
  #    "from Deshevle.dbo._rClass where IsForPublish=1 and IsPdNode=1 ".
  #    "order by ClCode;<br>".
  #    "alter table classes add index i_parent(level, parent);\n".
  #    "alter table classes add index i_code(code);\n".
  #    "alter table classes add fulltext index FTI(title);";
  #    'select IDGlossary as ID, GlName as title, GlText as value, RD into glossary from Deshevle.dbo._Glossary where GlText is not null;';
  #    'select IDChr as ID, IDClass, IDGlossary, ClCode as code, ChrName as title, ChrMeasure as measure, ChrType as type, ChrStyle as style, IsMain as main, RD '.
  #    'into attrs '.
  #    'from Deshevle.dbo._rChr '.
  #    'order by ClCode;'.
  #    'alter table attrs add index FK_classes(IDClass);'.
  #    'alter table attrs add index FK_glossary(IDGlossary);'.
  #    'alter table attrs add index i_code(code);'.
  #    'alter table attrs add index i_title(title);';
       'select IDClass, ClCode as code, ClAltName as title into altnames from Deshevle.dbo._AltClassName order by ClCode;'.
       'alter table altnames add index FK_class(IDClass);'.
       'alter table altnames add index i_code(code);'.
       'alter table altnames add index i_title(title);';

  #
  #    'select top 100000 IDPd as ID, IDClass, IDVendor, PdCode, PdName, PdComment, PdMadeInCountry, PdMadeYear, PdBooklet, '.
  #                    'IsImage, IsBooklet, RD, IsChr, PdGetCount, UserName, IsPdMImage, Sorting, IsLog, IsWeb, '.
  #                    'HOSTNAME, IsVisible, PdCodeForMarket, BuyWPrice, stamp, PdContext, IDMerge '.
  #    'into pd from _Pd;';
  #    'select IDClass as ID, ClParent as parent, ClCode as code, ClName as title, IsForPublish as published, RD '.
  #    'into classes '.
  #    'from Deshevle.dbo._rClass where IsForPublish=1 and IsPdNode=1 order by ClCode;';
  $qs{'destination'} = 'mysql';
  $qs{'DB'}          = 'deshevle';
  $qs{'engine'}      = 'MyISAM';
  $qs{'PK'}          = 'ID';
  $qs{'x_new'}       = 1;
  $qs{'x_drop'}      = 1;
}
#
# Params -----------------------------------------------------------------------
#
my $provider         = $qs{'provider'}    || '';
my $database         = $qs{'database'}    || '';
my $charset          = $qs{'charset'}     || '';
my $query            = $qs{'query'}       || '';
my $destination      = $qs{'destination'} || '';
my $DB               = $qs{'DB'}          || '';
my $engine           = $qs{'engine'}      || '';
my $PK               = $qs{'PK'}          || '';
my $x_new            = $qs{'x_new'}       && ' checked ' || '';
my $x_drop           = $qs{'x_drop'}      && ' checked ' || '';
my $x_timestamp      = $qs{'x_timestamp'} && ' checked ' || '';
my $x_strip          = $qs{'x_strip'}     && ' checked ' || '';
my $state            = $qs{'state'}       || '';
#
# Global definitions -----------------------------------------------------------
#
my $dbs;             # Ssource database handler
my $dbd;             # Destination database handler
my @sql_query;       # Source SQL query array
my $owner;           # Source DB schema
my $schema;          # Destination DB schema
my $qs;              # Current *select* query string - *query*
my @columns;         # Query columns list
my %items;           # Parsed query items
my $progress;        # Progress mode: 1/0
my $table;           # Destination table name
my $tmp;             # Temporary table name
my $IsError;         # Error flag
my @errors;          # Errors list
my $msg;             # Error messages

#
# Connect to the database ------------------------------------------------------
#
$dbs = &db_connect( $provider, $database, $charset );
$owner = &q_defs( $provider, 'schema' );
$schema = &q_defs( $destination, 'schema' );
#
# Get SQL query batch ----------------------------------------------------------
#
@sql_query = split /;/, &plain_text(&txt2html($query), 1);
#print "$_<br>" foreach (@sql_query);
# Open Log handle --------------------------------------------------------------
#
open my $LOG_HANDLE, '>>', '../htdocs/log/exporter.log' or die;
#print $LOG_HANDLE "$query\n";
#
# ------------------------------------------------------------------------------
#
@body = (
  "<table cellspacing=\"5\" cellpadding=\"0\" border=\"0\">\n",
  "<tr>\n",
  "  <td nowrap><strong>Destination <font face=\"courier\">-></font> DB:</strong></td>\n",
  "  <td>\n",
  "    <select id=\"destination\" name=\"destination\" size=\"1\" onchange=\"javascript:changeDestination();\">\n"
);

print "$_" foreach @body;

print &parse_select($destination, [':', 'mssql:MS SQL Server', 'mysql:MySQL']);

@body = (
  "    </select>\n",
  "  </td>\n",
  "  <td nowrap><strong>DATABASE</strong></td>\n",
  "  <td><input type=\"text\" id=\"DB\" value=\"".$DB."\"></td>\n",
  "  <td><input type=\"button\" name=\"run_export\" value=\"Export\" style=\"width:100px;\" onclick=\"javascript:runExport();\"></td>\n",
  "</tr>\n",
  "<tr>\n",
  "  <td colspan=\"2\" rowspan=\"3\">\n",
  "    <table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n",
  "    <tr>\n",
  "      <td><input id=\"x_new\" type=\"checkbox\" value=\"1\"".$x_new."></td>\n",
  "      <td nowrap><label for=\"x_new\"><font size=\"-2\">create new</font></label></td>\n",
  "    </tr><tr>\n",
  "      <td><input id=\"x_drop\" type=\"checkbox\" value=\"1\"".$x_drop."></td>\n",
  "      <td nowrap><label for=\"x_drop\"><font size=\"-2\">delete all rows before</font></label></td>\n",
  "    </tr><tr>\n",
  "      <td><input id=\"x_timestamp\" type=\"checkbox\" value=\"1\"".$x_timestamp."></td>\n",
  "      <td nowrap><label for=\"x_timestamp\"><font size=\"-2\">use timestamp</font></label></td>\n",
  "    </tr><tr>\n",
  "      <td><input id=\"x_strip\" type=\"checkbox\" value=\"1\"".$x_strip."></td>\n",
  "      <td nowrap><label for=\"x_strip\"><font size=\"-2\">strip all varchar</font></label></td>\n",
  "    </tr>\n",
  "    </table>\n",
  "  </td>\n",
  "  <td align=\"right\" nowrap><strong>ENGINE</strong></td>\n",
  "  <td>\n",
  "    <select id=\"engine\" name=\"engine\" size=\"1\" style=\"width:124px;\">\n",
);

print "$_" foreach @body;

print &parse_select($engine, [':', 'myisam:MyISAM', 'innodb:INNODB']);

@body = (
  "    </select>\n",
  "  </td>\n",
  "</tr>\n",
  "<tr>\n",
  "  <td align=\"right\" nowrap><strong>PK</strong></td>\n",
  "  <td><input type=\"text\" id=\"PK\" value=\"".$PK."\"></td>\n",
  "</tr>\n",
  "<tr>\n",
  "  <td align=\"right\" nowrap>&nbsp;</td>\n",
  "  <td>&nbsp;</td>\n",
  "</tr>\n",
);

print "$_" foreach @body;

$progress = 0;
$query = ''; # this will be just current query

if( !$database && @sql_query ) {
  push @errors, 'Source database not selected!';
  @sql_query = ();
}

GO:

while ( !$progress and @sql_query and
         my ($query, $type) = &check_sql_query( $provider, shift @sql_query, 1 ) ) {
  if( !$query ) {
    next;
  }
  if( $type != 1 && $type != 3 ) {
    push @errors, "Query is not valid: $query";
    next;
  }
  my $now = strftime "%d.%m.%Y %H:%M", localtime;
  print $LOG_HANDLE "$now: $query\n";

  if( $IsDebug == 1 ) { print "$query\n"; }

  if( $type == 1 ) {
    %items = &q_parsed_select( $provider, $query );
    $tmp   = '__exp__'.int(rand(1000000));
    $table = $items{'into_table'};
  }

  my $IsDestinationExists = 0;
  my $step = 0;

  while( $dbs->ping && $step < 7 && $table ) {
    if( $IsDebug ) {
      print "step: $step\n";
    }
    # Create or validate destination table
    # ------------------------------------
    if( $step == 0 ) {
      $dbd = &db_connect( $destination, $DB, $charset );
      # +++++++++++++++++++++++++++++++++++++++++++++ #
      if( !$dbd->ping ) {
        last;
      }
      ($IsError, $msg) = &execDropTable(
                 $dbd, $destination, $DB, $schema, $table,
                 $IsDebug
                 )
                 unless !$x_new or $type == 3;
      if( &IsTableExists( $dbd, $destination, $DB, $schema, $table, $IsDebug ) ) {
          $IsDestinationExists = 1;
      }
      if( $type == 1 ) {
        if( $IsDestinationExists ) {
          if( $provider eq $destination ) {
            $step = 4;
          }
        }
      }
    # Execute command under destination table
    # ---------------------------------------
      elsif( $type == 3 ) {
        if( $IsDestinationExists ) {
          eval {
            $dbd->do( $query );
          };
          if( $@ ) {
            push @errors, $@;
          }
        }
        $step = 6;
      }
    }
    # Create temporary table for the given recordset (run *into*)
    # -----------------------------------------------------------
    elsif( $step == 1 ) {
      ($IsError, $msg) = &execSelectInto(
                 $dbs, $provider, $database, $owner, $tmp,
                 1,
                 \%items,
                 $IsDebug
                 );
    }
    # Get source recordset structure (column definitions)
    # ---------------------------------------------------
    elsif( $step == 2 ) {
      ($IsError, $msg, @columns) = &execGetColumnsInfo(
                 $dbs, $provider, $database, $owner, $tmp,
                 $IsDebug
                 );
    }
    # Drop temporary table
    # --------------------
    elsif( $step == 3 ) {
      ($IsError, $msg) = &execDropTable(
                 $dbs, $provider, $database, $owner, $tmp,
                 $IsDebug
                 );
    }
    # Create or validate destination table
    # ------------------------------------
    elsif( $step == 4 ) {
      ($IsError, $msg) = &execCloneTable(
                 $dbd, $destination, $DB, $schema, $table, $engine, $PK,
                 \@columns,
                 $IsDebug
                 )
                 unless $IsDestinationExists;
      $step = 5;
    }
    # Get destination recordset structure (column definitions)
    # --------------------------------------------------------
    elsif( $step == 5 ) {
      ($IsError, $msg, @columns) = &execGetColumnsInfo(
                 $dbd, $destination, $DB, $schema, $table,
                 $IsDebug
                 );
    }
    # Export data
    # -----------
    elsif( $step == 6 ) {
      ($IsError, $msg) = &execDeleteFromTable(
                 $dbd, $destination, $DB, $schema, $table, '',
                 $IsDebug
                 )
                 unless !$x_drop or $type == 3;
      ($IsError, $msg) = &execExportTable(
                 $dbs, $provider, $database, $owner,
                 $dbd, $destination, $DB, $schema, $table, $engine, $PK,
                 $query,
                 \@columns,
                 \%items,
                 $x_strip,
                 $IsDebug
                 );
    }

    if( $step == 6 || $IsError ) {
      if( !$IsError ) {
        $dbd->commit() or die $dbd->errstr;
      }
      &db_close( $dbd );
      # ++++++++++++++ #
    }

    if( $IsError ) {
      push @errors, $_ foreach (@$msg);
      last GO;
    }

    $step++;
  }
}

if( !$progress ) {
  @body = (); # "&nbsp;\n"
} else {
  @body = (
  "<tr>\n",
  "  <td colspan=\"5\" style=\"border:1px solid #8080FF;\" width=\"570\" height=\"40\">\n",
  "    <iframe id=\"progress_frame\" name=\"progress_frame\" width=\"560\" height=\"40\"",
  "     frameborder=\"0\" scrolling=\"no\"",
  "     src=\"/cgi-bin/progress.pl".
  "        ?provider=".$provider.
  "        &database=".$database.$owner.
  "        &charset=".$charset.
  "        &destination=".$destination.
  "        &DB=".$DB.$schema.
  "        &table=".$table.
  "        &query=".$query.
  "    \"></iframe>\n",
  "  </td>\n",
  "</tr>\n",
  );
}

print "$_" foreach @body;
#
# Close Log handle -------------------------------------------------------------
#
close $LOG_HANDLE or die;
#
# Disconnect from the database -------------------------------------------------
#
&db_close($dbs);
#
# Errors log -------------------------------------------------------------------
#
my $err_div = "<br>\n";

if( @errors ) {
  $err_div .= "<div class=\"errors\" id=\"errors\">\n";
  foreach my $x (@errors) {
    $err_div .= "<p>".&txt2html($x)."</p>\n";
  }
  $err_div .= "</div>\n"
}
#
# ------------------------------------------------------------------------------
#
@body = (
  "</table>\n",
  "</div>\n",
  "\n",
  "<input id=\"provider\" name=\"provider\" type=\"hidden\" value=\"$provider\">\n",
  "<input id=\"charset\" name=\"charset\" type=\"hidden\" value=\"$charset\">\n",
  "<input id=\"database\" name=\"database\" type=\"hidden\" value=\"$database\">\n",
  "<input id=\"destination\" name=\"destination\" type=\"hidden\" value=\"$destination\">\n",
  "<input id=\"DB\" name=\"DB\" type=\"hidden\" value=\"$DB\">\n",
  "<input id=\"engine\" name=\"engine\" type=\"hidden\" value=\"$engine\">\n",
  "<input id=\"PK\" name=\"PK\" type=\"hidden\" value=\"$PK\">\n",
  "<input id=\"x_new\" name=\"x_new\" type=\"hidden\" value=\"$x_new\">\n",
  "<input id=\"x_drop\" name=\"x_drop\" type=\"hidden\" value=\"$x_drop\">\n",
  "<input id=\"x_timestamp\" name=\"x_timestamp\" type=\"hidden\" value=\"$x_timestamp\">\n",
  "<input id=\"x_strip\" name=\"x_strip\" type=\"hidden\" value=\"$x_strip\">\n",
  "<input id=\"sql_query\" name=\"sql_query\" type=\"hidden\" value=\"".&html2txt(join(';', @sql_query))."\">\n",
  "<input id=\"query\" name=\"query\" type=\"hidden\" value=\"".&html2txt(&strip($query))."\">\n",
  "<input id=\"progress\" name=\"progress\" type=\"hidden\" value=\"".($progress ? '1' : '')."\">\n",
  "<input id=\"state\" name=\"state\" type=\"hidden\" value=\"$state\">\n",
  "</form>\n",
  $err_div,
  "</body>\n",
  "</html>"
);

print "$_" foreach @body;

exit(0);