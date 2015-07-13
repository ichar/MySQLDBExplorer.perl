#!C:/Perl/bin/perl

# Get query string -------------------------------------------------------------
#
# Returns:
#   $query_string - String.
#
sub get_query {
  my $query = $ENV{'QUERY_STRING'};
  if( $query eq '' ) {
    my $posted = $ENV{'CONTENT_LENGTH'};
    if( $posted ) {
      my $x;
      while ( !$query && sysread(STDIN, $x, 1024) ) {
        $query .= $x;
      }
    }
  }
  return &parse_query($query); # if( $query ne '' )
}

# Extract (parse) query string attrs -------------------------------------------
#
# Arguments:
#   #query_string - String.
#
# Returns:
#   Hash: ('attr' => 'value', ...).
#
sub parse_query {
  my @query = split('&', shift(@_));
  my %vals;
  if( @query ) {
    foreach $element(@query) {
      my ($p, $v) = split('=', $element);
      $vals{decode($p)} = decode($v);
    }
  }
  return %vals;
}

# Query string decoding --------------------------------------------------------
#
# Arguments:
#   #query_string - String.
#
# Returns:
#   $query_string - String.
#
sub decode {
  my $s = shift(@_);
  $s =~ s/\+/ /g;
  $s =~ s/%([0-9A-F]{2})/pack('C', hex($1))/eg;
  return $s;
}

# HTML chr encoding ------------------------------------------------------------
sub html2txt {
  my $s = shift(@_);
  if( !$s ) { return ''; }
  $s =~ s/&/&amp;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  $s =~ s/"/&quot;/g;
  return $s;
}

# HTML chr decoding ------------------------------------------------------------
sub txt2html {
  my $s = shift(@_);
  if( !$s ) { return ''; }
  $s =~ s/&lt;/</g;
  $s =~ s/&gt;/>/g;
  $s =~ s/&quot;/"/g;
  $s =~ s/&amp;/&/g;
  $s =~ s/&nbsp;/ /g;
  #$s =~ s/\n//g;
  return $s;
}

# TEXT cleaner -----------------------------------------------------------------
sub txt_cleanup {
  my $s = shift(@_);
  if( !$s ) { return ''; }
  $s =~ s/\t\f\r\a\b//g;
  #$s =~ s/\x84/&quot;/g;
  #$s =~ s/\x91/&lsquo;/g;
  #$s =~ s/\x92/&rsquo;/g;
  #$s =~ s/\x93/&ldquo;/g;
  #$s =~ s/\x94/&rdquo;/g;
  #$s =~ s/\x95/&middot;/g;
  #$s =~ s/\xab/&laqua;/g;
  #$s =~ s/\xbb/&raqua;/g;
  #$s =~ s/\x96/&ndash;/g;
  #$s =~ s/\x97/&ndash;/g;
  #$s =~ s/\x{0000}-\x{fffd}//g;
  $s =~ s/[\x00-\x1f\x7f-\xbf]+//g;
  return $s;
}

# Parses 'select' tag ----------------------------------------------------------
#
# Arguments:
#   $selected - selected item, String
#   $values - ref to list of items: 'id:value'
#
# Returns:
#   List of (<parsed option tag 1>, ...)
#
sub parse_select {
  my ($selected, $array) = @_;
  my @values;
  foreach (@$array) {
    my ($id, $value) = split(':', $_);
    my $s = ( $id eq $selected ? ' selected' : '' );
    push @values, "<option value=\"$id\"$s>$value</option>\n";
  }
  return @values;
}

return 1;