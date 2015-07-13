#!C:/Perl/bin/perl

use warnings;
use strict;

use CGI::ProgressBar qw/:standard/;

$| = 1; # Do not buffer output

my $data;
my $cgi = CGI->new(\&bar_hook, $data);

our $hook_called = 0;
our $total_bytes = 0;

if (not $hook_called){
  print $cgi->header,
        $cgi->start_html( -title=>'A Simple Example', ),
        $cgi->h1('Simple Upload-hook Example');
}

  print $cgi->start_form( -enctype=>'application/x-www-form-urlencoded'),
        $cgi->filefield( 'uploaded_file'),
        br,
        br,
        $cgi->submit( 'submit' ),
        br,
        #progress_bar( -from=>1, -to=>100, -debug=>1 ),
        $cgi->end_form,p;

if( $cgi->param('uploaded_file') ) {
  print 'uploaded_file: '.param('uploaded_file');
}


sub bar_hook {
  my ($filename, $buffer, $bytes, $data) = @_;

  $total_bytes += 100;

  if (not $hook_called) {
    print header,
        start_html( -title=>'Simple Upload-hook Example', ),
        h1('Uploading'),
        p(
           "Have to read <var>$ENV{CONTENT_LENGTH}</var> in blocks of <var>$bytes</var>, total blocks should be ",
           ($ENV{CONTENT_LENGTH}/$bytes)
        ),
        progress_bar( -from=>1, -to=>100, -debug=>1 ); #($ENV{CONTENT_LENGTH}/$bytes)
        $hook_called = 1;
  } else {
    # Called every $bytes, I would have thought.
    # But calls seem to go on much longer than $ENV{CONTENT_LENGTH} led me to believe they ought:
    print update_progress_bar;
    print "$ENV{CONTENT_LENGTH} ... $total_bytes ... $hook_called ... div="
       .($hook_called/$total_bytes)
       ."<br>";
  }

  sleep 1;
  $hook_called += $total_bytes;
}

print hide_progress_bar;

if ($hook_called){
  print p('All done after '.$hook_called.' calls');
}

print $cgi->end_html;

exit;
