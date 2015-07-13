#!C:/Perl/bin/perl

# Strips string (drop all leading and closing spaces) --------------------------
#
# Arguments:
#   $value - string,
#
# Returns:
#   String.
#
sub strip {
  my $value = shift;
  if( $value ) {
    #$value =~ s/\s*(.*)\s*/$1/g;
    $value =~ s/\s*(\S.*\S|\S)\s*/$1/g;
  }
  return $value || '';
}

# Checks given string inside an array (python's *in*) --------------------------
#
# Arguments:
#   $value - string,
#   $array - ref to string array.
#
# Returns:
#   Boolean: 1/0 - exists or not.
#
sub in {
  my ($value, $array) = @_;
  foreach my $x (@$array) {
    if( $x eq $value ) {
      return 1;
    }
  }
  return 0;
}

# Performs replacement inside the givven string --------------------------------
#
# Arguments:
#   $value - string,
#   $rw - regexp *what*
#   $rt - regexp *to*
#
# Returns:
#   String: resulting string.
#
sub replace {
  my ($value, $rw, $rt) = @_;
  if( $value ) {
    my $v = $value;
    $v =~ s/$rw/$rt/g;
    return $v;
  }
  return '';
}

# Drops all HTML tags inside the given string ----------------------------------
sub plain_text {
  my ($value, $no_comments) = @_;
  if( $no_comments ) {
    $value =~ s/<br.*?>/\n/gi;
    $value =~ s/\#.*?\n//g;
  }
  $value =~ s/<[a-zA-Z\/]+.*?>//g;
  $value =~ s/[\a\b\f\r]+//g;
  $value =~ s/[\n\t]+/ /g;
  return &strip($value);
}

return 1;