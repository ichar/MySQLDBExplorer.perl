#!C:/Perl/bin/perl

use strict;
use DBI;
use CGI;      # or any other CGI:: form handler/decoder
use CGI::Ajax;

my $IsDebug = 0;

my $cgi = new CGI;
my $pjx = new CGI::Ajax( 'exported_func' => \&RefreshProgress );

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
      #"select IDClass as ID, ClCode as code, ClName as title from Deshevle.dbo._rClass order by ClCode";
      "select * from Deshevle.dbo._rClass order by ClCode";
  $qs{'destination'} = 'mysql';
  $qs{'DB'}          = 'deshevle';
  $qs{'table'}       = 'classes';
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
my $table            = $qs{'table'}       || '';
#
# Global definitions -----------------------------------------------------------
#
my $dbs;             # Ssource database handler
my $dbd;             # Destination database handler
my $sts;             # Source handler
my $std;             # Destination handler

my %items;           # Parsed query items

my $progress_width;  # Progress bar width (in pixels)
my $progress_step;   # Progress bar step
my $counter;         # Progress counter
my $total_steps;     # Total steps number
my $step;            # Current step

my @errors;          # Errors list

my $num_of_fields;   # Number of recordset fields
my $rows;            # Source recordset rows counter
my $qs;              # Statement

my $fetch_total_rows;# Total selected rows
my @fetch_status;    # Status of fetch result
my $fetch_step;      # Fetch step
my $f;               # Fetch counter
#
# Progress subroutine definitions ----------------------------------------------
#
sub RefreshProgress {
  #our ( $dbs, $dbd, $sts, $std, %items, $progress_width, $progress_step,
  #      $counter, $total_steps, $step, @errors, $num_of_fields, $rows, $qs,
  #      $fetch_total_rows, @fetch_status, $fetch_step, $f );

  my $c = int(shift) || 0;

  # Initialize
  if( $c == 0 ) {
    init();
  }

  # Make counter evolution
  if( $c < 100 && $total_steps > 0 ) {
    $step++; # = $s;
    $counter = ( 100 / $total_steps ) * $step;
  } else {
    $counter = 100;
  }

  # Do next iteration
  if( $dbs->ping ) {
    run();
  }

  # Terminate
  if( $c == 100 ) {
    term();
  }

  # Return progress content
  return ( join('', &progress_body()), $counter, $query . "(rows: " . $rows . ")" );
}

sub progress_body {
  my $bar_width = $step * $progress_step;
  my @html = (
  "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n",
  "<tr>\n",
  "  <td width=\"".$progress_width."px\" style=\"padding: 1px 1px 1px 1px;border:1px solid #8080FF;\" nowrap>\n",
  "    <table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n",
  "    <tr>\n",
  "      <td id=\"bar\" bgcolor=\"blue\"><img src=\"/images/spacer.gif\" height=\"10\" width=\"".$bar_width."\"></td>\n",
  "    </tr>\n",
  "    </table>\n",
  "  </td>\n",
  "  <td style=\"padding-left:3px;\"><span><font size=\"-2\">".$counter."%</font></span></td>\n",
  "</table>\n",
  );

  return @html;
}
#
# MAIN -------------------------------------------------------------------------
#
sub init {
  # Connect to the database
  $dbs = &db_connect( $provider, $database, $charset );
  $dbd = &db_connect( $destination, $DB, $charset );

  # Prepare and execute source *select*
  %items = &q_parsed_select( $provider, $query );
  $rows = &execSelectCount( $dbs, '', 'select count(*) from '.$items{'from'}.( $items{'where'} ? ' '.$items{'where'} : '' ) );

  if( !$rows) {
    push @errors, 'Source recordset is empty!';
  }
  elsif( !$query ) {
    push @errors, 'No source query!';
  }
  else {
    $sts = $dbs->prepare( $query );
    eval {
      $sts->execute();
    };
    $num_of_fields = $sts->{NUM_OF_FIELDS};
    if ($@) {
      push @errors, $@;
    }
  }

  # Prepare destination *insert*
  if( $num_of_fields ) {
    $qs  = "insert into $table values(".('?,' x ($num_of_fields-1)).'?)';
    $std = $dbd->prepare( $qs );
  }

  # Init progress counter
  $progress_width = 500;

  if( $rows ) {
    $counter = 0;
    $step = 0;

    $total_steps = ( $rows > 10000 ? 100 : ( $rows > 5000  ? 50  : ( $rows > 2500  ? 25  :
                   ( $rows > 1000  ? 20  : ( $rows > 500   ? 10  :
                   ( $rows > 100   ? 5   : 1
    ) ) ) ) ) );

    $progress_step = int($progress_width / $total_steps);
    $fetch_step = int($rows / $total_steps);
    $fetch_total_rows = 0;
  }
  else {
    $counter = 100;
  }
}
#
# Exporting subroutine ---------------------------------------------------------
#
sub fetch_sub {
  if( $fetch_total_rows > $rows ) {
    #pass
  } elsif( $f < $fetch_step || $step == $total_steps ) {
    ++$f;
    ++$fetch_total_rows;
    return $sts->fetchrow_arrayref;
  }
}

sub run {
  $f = 0;
  my $rc = $std->execute_for_fetch(\&fetch_sub, \@fetch_status);
  @errors = grep { ref $_ } @fetch_status;
}
#
# Terminate --------------------------------------------------------------------
#
sub term {
  # Disconnect from the destination database
  &db_close($dbd);
  # Disconnect from the source database
  &db_close($dbs);
}
#
# DEBUG ------------------------------------------------------------------------
#
if( $IsDebug == 1 ) {
  my $i = 0;
  $counter = $total_steps = 0;

  while (1) {
    $i++;
    if( $total_steps && $i > $total_steps ) {
      last;
    }
    &RefreshProgress( $counter );
    if( $i == 1 ) {
      print "init: rows=$rows steps=$total_steps progress_step=$progress_step fetch_step=$fetch_step qs=$qs\n";
    }
    printf "%s: counter=%03s rows=%05s\n", $step, $counter, $fetch_total_rows;

    if( @errors ) {
      &term();
      print "Errors:\n";
      foreach (@errors) { print "$_\n"; }
      last;
    }
  }
}
#
# ------------------------------------------------------------------------------
#
print $pjx->build_html($cgi, \&progress_html);

sub progress_html {
  my $q = substr($query, 0, 150);
  my $html = <<EOHTML;

<HTML>
<BODY leftmargin="5" topmargin="2" rightmargin="5" bottommargin="2">
<table cellspacing="2" cellpadding="0" border="0">
<tr>
  <td nowrap><span><font size="-2"><div id="q">$q</div></font></span><td>
</tr>
<tr>
  <td><div id="progress_bar"></div></td>
</tr>
</table>
<script language="JavaScript">

function js_process_func() {
    var p_body = arguments[0];
    var counter = parseInt(arguments[1]);
    var query = arguments[2];

    document.getElementById('progress_bar').innerHTML = p_body;
    document.getElementById('counter').value = counter;
    document.getElementById('q').innerHTML = query;
    if( counter < 100 ) {
        exported_func( ['counter','NO_CACHE'], [js_process_func] );
        return;
    }

    window.parent.parent.runProgress();
}

window.onload = function() { js_process_func('', 0, '') };
</script>

<input type="hidden" name="counter" id="counter" value="" size="3">
<input type="hidden" name="query" id="query" value="">

</BODY>
</HTML>

EOHTML

  return $html;
}

exit(0);