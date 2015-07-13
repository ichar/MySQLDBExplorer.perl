#!C:/Perl/bin/perl

# Check SQL query before execute -----------------------------------------------
#
# Arguments:
#   $provider - provider name, String
#   $query - query, String
#
# Returns:
#   Tuple (<type>, <parsed query>) as:
#     Int: <type>
#      0 - 'select'
#      1 - 'select into'
#      2 - 'show'
#      3 - 'command'
#     List: (<parsed query>, ...)
#
sub check_sql_query {
  my ($provider, $query, $unlimited) = @_;
  my  $q = &plain_text( $query );
  my  @w = split(' ', $q);
  my  $l = scalar @w;
  my  $t;

  #print "-> ".$l;
  #print " ".$_ foreach @w;
  #print "\n";
  if( $l == 0 ) {
    return ('', 0);
  }
  elsif ( substr($w[0], 0, 1) eq '#' ) {
    return ('', 0);
  }
  elsif ( lc($w[0]) eq "select" ) {
    if( $l > 2 && !$unlimited ) {
      if( $provider eq 'mssql' && lc($w[1]) ne "top" && lc($w[1]) ne "distinct" ) {
        $q = "select top 1000 ";
        $q .= $_." " foreach @w[1..$l-1];
      }
      elsif( $provider eq 'mysql' && lc($w[$l-2]) ne "limit" ) {
        $q .= " limit 1000"
      }
    }
    $t = &in('into', \@w); # 'select|select into' type
  }
  elsif ( lc($w[0]) eq "show" ) {
    $t = 2;  # just like 'select' type
  }
  else {
    $t = 3; # another 'insert/update/delete' type
  }
  return ($q, $t);
}

# Run query and return first item of recordset ---------------------------------
#
# Arguments:
#   $query - query statement handler.
#
# Returns:
#   List of (<record 1-0>, <record 2-0>, ...)
#
sub get_tuple {
  my $sth = shift;
  my @values = ();

  while ( my @x = $sth->fetchrow_array() ) {
    if( scalar @x ) {
      push @values, &strip($x[0]);
    }
  }
  return @values;
}

# Check either given table exist in the database -------------------------------
#
# Arguments:
#   $dbh - database handler, should be open
#   $provider - 'mssql|mysql', String
#   $database - database name
#   $schema - schema name
#   $table - table name
#   $IsDebug - debug mode.
#
sub IsTableExists {
  my ($dbh, $provider, $database, $schema, $table, $IsDebug) = @_;
  my  $qs = &q_defs(
            $provider, 'show tables', {'database' => $database}
      );

  if( $IsDebug == 1 ) {
    print "*is table exists*: $qs\n";
  }
  my $sth = $dbh->prepare( $qs );
  $sth->execute() or die;
  my @r_tables = &get_tuple($sth);

  return &in(&strip($table), \@r_tables);
}

# Execute *create table statement* ---------------------------------------------
#
# Arguments:
#   $dbh - database handler, should be open
#   $provider - 'mssql|mysql', String
#   $r_items - source query parsed items, Ref to Hash
#   $top - records *top* count
#   $table - into table name
#   $IsDebug - debug mode.
#
sub execSelectInto {
  my ($dbh, $provider, $database, $schema, $table, $top, $r_items, $IsDebug) = @_;
  my  $qs = &q_make_select_into(
            $provider, $table, $top, $r_items
      );

  if( $IsDebug == 1 ) {
    print "*select into*: $qs\n";
  }
  eval {
    $dbh->do( $qs );
  };
  if( $@ ) {
    return (1, \($@));
  }
}

# Returns column's information -------------------------------------------------
#
# Arguments:
#   $dbh - database handler, should be open
#   $provider - 'mssql|mysql', String
#   $database - database name
#   $schema - schema name
#   $table - table name
#   $IsDebug - debug mode.
#
# Returns:
#   Tuple: (<error>, <msg>, <columns>).
#     <error>   - Binary, 1/0, if error was happen or not
#     <msg>     - String, error message string
#     <columns> - Ref to Array, is a mapping list of column's attrs (@attrs),
#     appropriate with columns attr key list such as:
#
#     ({column1}, ... )
#
#     column - is a Ref to Hash of attrs.
#
sub execGetColumnsInfo {
  my ($dbh, $provider, $database, $schema, $table, $IsDebug) = @_;
  my  $qs = &q_defs(
            $provider, 'show columns', {'table' => $database.$schema.$table}
      );
  my  $stt = $dbh->prepare( $qs );
  my  @info;

  if( $IsDebug == 1 ) {
    print "*get columns info*: $qs\n";
  }
  eval {
    $stt->execute();
  };
  if( $@ ) {
    return (1, \($@));
  }

  my @columns = &get_tuple( $stt );
  my $d = ($provider eq 'mssql' ? $database : undef);
  my $s = ($provider eq 'mssql' ? &replace( $schema, '\.', '' ) : $database);
  # Columns' infromation keys:
  my @attrs = qw(TABLE_CAT TABLE_SCHEM TABLE_NAME COLUMN_NAME DATA_TYPE
                 TYPE_NAME COLUMN_SIZE BUFFER_LENGTH DECIMAL_DIGITS
                 NUM_PREC_RADIX NULLABLE REMARKS COLUMN_DEF SQL_DATA_TYPE
                 SQL_DATETIME_SUB CHAR_OCTET_LENGTH ORDINAL_POSITION
                 IS_NULLABLE);

  $stt->finish();

  foreach my $c (@columns) {
    if( $IsDebug == 1 ) { print "$database$schema$c -----------------------\n"; }
    my  $stc = $dbh->column_info( $d, $s, $table, $c );
    my  $column = $stc->fetchall_arrayref() or die;
    my  %col;

    $stc->finish();

    foreach my $x (@$column) {
      my $i = 0;
      foreach my $v (@$x) {
        if( $i == scalar @attrs ) {
          last;
        }
        $v = '' unless defined $v;
        $col{$attrs[$i]} = $v;
        if( $IsDebug == 1 ) { print $attrs[$i]." = ".$col{$attrs[$i]}."\n"; }
        $i++;
      }
    }

    push @info, \%col;
  }

  # To find the type name for the fields in a select statement you can do:
  #@names = map { scalar $dbh->type_info($_)->{TYPE_NAME} } @{ $sth->{TYPE} }

  return (0, '', @info);
}

# Execute *drop table statement* -----------------------------------------------
#
# Arguments:
#   $dbh - database handler, should be open
#   $provider - 'mssql|mysql', String
#   $database - database name
#   $schema - schema name
#   $table - table name
#   $IsDebug - debug mode.
#
sub execDropTable {
  my ($dbh, $provider, $database, $schema, $table, $IsDebug) = @_;
  my  $qs = &q_make_drop_table(
            $provider, $database, $schema, $table
      );

  if( $IsDebug == 1 ) {
    print "*drop table*: $qs\n";
  }
  eval {
    $dbh->do( $qs );
  };
  if( $@ ) {
    return (1, \($@));
  }
}

# Execute *delete from table statement* ----------------------------------------
#
# Arguments:
#   $dbh - database handler, should be open
#   $provider - 'mssql|mysql', String
#   $database - database name
#   $schema - schema name
#   $table - table name
#   $where - where string without keyword *where*
#   $IsDebug - debug mode.
#
sub execDeleteFromTable {
  my ($dbh, $provider, $database, $schema, $table, $where, $IsDebug) = @_;
  my  $qs = &q_make_delete_from_table(
            $provider, $database, $schema, $table, $where
      );

  if( $IsDebug == 1 ) {
    print "*delete from table*: $qs\n";
  }
  eval {
    $dbh->do( $qs );
  };
  if( $@ ) {
    return (1, \($@));
  }
}

# Execute *create table statement* by given columns spec -----------------------
#
# Arguments:
#   $dbh - database handler, should be open
#   $provider - 'mssql|mysql', String
#   $database - database name
#   $schema - schema name
#   $table - table name
#   $engine - engine name, String
#   $PK - primary key columns' name
#   $r_columns - columns spec, Ref to Array
#   $IsDebug - debug mode.
#
sub execCloneTable {
  my ($dbh, $provider, $database, $schema, $table, $engine, $PK, $r_columns, $IsDebug) = @_;
  my  $qs = &q_make_clone_table(
            $provider, $database, $schema, $table, $r_columns, $engine, $PK
       );

  if( $IsDebug == 1 ) {
    print "*clone table*: $qs\n";
  }
  eval {
    $dbh->do( $qs );
  };
  if( $@ ) {
    return (1, \($@));
  }
}

# Execute *select count(*) from ...* by given query ---------------------------
#
# Arguments:
#   $dbh - database handler, should be open
#   $table - table name
#
# Returns:
#   $rows - rows counter (0 or <number>).
#
sub execSelectCount {
  my ($dbh, $table, $query) = @_;
  my  $rows = 0;
  my  $stc;

  if( !$query && $table ) {
    $query = "select count(*) from ".$table;
  }

  if( $query ) {
    $stc = $dbh->prepare( $query );

    eval {
      $stc->execute() or die;
    };
    if ($@) {
      $rows = 0;
    } else {
      my @s = $stc->fetch();
      $rows = $s[0][0];
    }
    $stc->finish();
  }

  return $rows;
}

# Execute *insert into statement* by given recordset ---------------------------
#
# Arguments:
#  Source:
#   $dbs - source database handler, should be open
#   $provider - 'mssql|mysql', String
#   $database - database name
#   $owner - schema name
#  Destination:
#   $dbd - database handler, should be open
#   $destination - 'mssql|mysql', String
#   $DB - database name
#   $schema - schema name
#   $table - table name
#   $engine - engine name, String
#   $PK - primary key columns' name
#  Spec:
#   $query - query, String
#   $r_columns - columns spec, Ref to Array
#   $r_items - source query parsed items, Ref to Hash
#   $IsDebug - debug mode.
#
sub execExportTable {
  my ($dbs, $provider, $database, $owner,
      $dbd, $destination, $DB, $schema, $table, $engine, $PK,
      $query, $r_columns, $r_items, $x_strip, $IsDebug) = @_;
  my  %items = %$r_items;
  my  @fetch_status;
  my  @errors;
  my  %qs;

  $qs = $items{'select'}. ' '.$items{'top'}.' '.$items{'args'}.' from '.$items{'from'}.
       ($items{'where'} ? ' '.$items{'where'} : '').
       ($items{'order'} ? ' '.$items{'order'} : '');

  # Prepare and execute source *select*
  my $sts = $dbs->prepare( $qs );
  eval {
     $sts->execute();
  };
  my $num_of_fields = $sts->{NUM_OF_FIELDS};
  if ($@) {
     push @errors, $@;
  }

  if( $num_of_fields ) {
    # Prepare destination *insert*
    $qs = "insert into $table values(".('?,' x ($num_of_fields-1)).'?)';
    my $std = $dbd->prepare( $qs );

    # Convert and export data
    my $fetch_sub = sub { &q_types_converter( $sts,
              $provider, $destination,
              $r_columns,
              $x_strip
              )
    };

    eval {
      my $rc = $std->execute_for_fetch($fetch_sub, \@fetch_status);
    };
    @fetch_status = grep { ref $_ } @fetch_status;

    if( @fetch_status ) {
      #print "$_[0]:$_[1]:$_[2]\n" foreach @errors;
      foreach $e (@fetch_status) {
        #print "$e:";
        #my @err = @$e;
        #print "$_:" foreach (@err);
        #print "\n";
        #print "$_:$err{$_}\n" foreach keys(%err);
        #print map {"$_:$err{$_}\n"} keys %err;
        push @errors, join(':', @$e);
      }
    }
  }

  return ( (@errors) ? 1 : 0, \@errors );
}

return 1;