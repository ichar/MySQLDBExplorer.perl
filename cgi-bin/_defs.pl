#!C:/Perl/bin/perl

my $mssql_query_defs = {
   'schema'          => '.dbo.',
   'show databases'  => 'select name from master.dbo.sysdatabases',
   'show tables'     => '',
   'show columns'    =>
     "select c.name, convert(int, ( select count(*) from syscolumns sc".
     " where sc.id=c.id AND sc.number=c.number AND sc.colid <= c.colid ))".
     " from sysobjects as o, syscolumns as c ".
     "where o.id=object_id('x-table-s') and c.id=o.id ".
     "order by 2",
};

my $mysql_query_defs = {
   'schema'          => '.',
   'show databases'  => 'SHOW DATABASES',
   'show tables'     => 'SHOW TABLES FROM x-database-s',
   'show columns'    => "SHOW COLUMNS FROM x-table-s",
};

my %mysql_types_map = (
   'bit'             => 'tinyint unsigned',
   'nchar'           => 'char',
   'nvarchar'        => 'varchar',
   'smalldatetime'   => 'datetime',
   'image'           => 'blob',
   'tinyint'         => 'tinyint unsigned',
   'text'            => 'text binary',
   'real'            => 'double',
);

my %mssql_types_map = (
);

my @sized_types = qw(char varchar);

# Returns column type associated with provider ---------------------------------
#
# Arguments:
#   $provider - 'mssql|mysql', String
#   $type - column type, String
#
# Returns:
#   String: type value.
#
sub q_type {
  my ($provider, $type) = @_;
  my  $qs = '';
  my  $key;

  $type = lc($type);

  if( !$provider || $provider eq 'mysql' ) {
    my @keys = keys(%mysql_types_map);
    return &in($type, \@keys) && $mysql_types_map{$type} ||
               $type;
  } else {
    my @keys = keys(%mssql_types_map);
    return &in($type, \@keys) && $mssql_types_map{$type} ||
               $type;
  }
}

sub q_size {
  my ($provider, $type, $size) = @_;
  if( &in(lc($type), \@sized_types) ) {
    return "($size)";
  }
  return '';
}

# Returns query defs perfoming needed substitution sets ------------------------
#
# Arguments:
#   $provider - 'mssql|mysql', String
#   $defs - key of the defs, String
#   $attrs - attrs {'key' => 'value', ...}, Ref to Hash.
#
# Returns:
#   String: defs value.
#
sub q_defs {
  my ($provider, $defs, $attrs) = @_;
  my  $qs = '';

  if( !$provider || $provider eq 'mysql' ) {
    $qs = $mysql_query_defs->{$defs} || '';
  } else {
    $qs = $mssql_query_defs->{$defs} || '';
  }

  foreach $key(keys(%$attrs)) {
    #print "-> $key:$attrs->{$key}\n";
    $p = "x-$key-s";
    $r = $attrs->{$key};
    $qs =~ s/$p/$r/g;
  }
  return $qs;
}
#
# ------------------------------------------------------------------------------
#
my $mssql_re_select = qr{
  ^(select\s+distinct|select)?     # 1: 'distinct'
    (\s+top\s+\d+\s+)?             # 2: 'top <ddd>'
    ([\w\,\s|\*]+?)                # 3: query attributes or '*'
    (\s+into\s+(\w+)\s+)?          # 4: 'into <table>',
                                   # 5: <table>
  from\s+(.+?)                     # 6: all text between 'from' and 'order'
    (\s+where\s+\w+)?              # 7: XXX
    (\s+order\s+by\s+(.+?))?       # 8: 'order by <fields desc|asc>'
                                   # 9: <field desc|asc>
  $}x;

my $mysql_re_select = '';

# Returns parsed 'select' query items ------------------------------------------
#
# Arguments:
#   $provider - 'mssql|mysql', String
#   $query - 'select' query, String.
#
# Returns:
#   Hash: 'select' items value.
#
sub q_parsed_select {
  my ($provider, $query) = @_;
  my  %items;

  if( !$provider || $provider eq 'mysql' ) {
    #pass
  } else {
    if( $query =~ m/$mssql_re_select/igs ) {
      my @keys = qw(select top args into into_table from where order order_by);
      my $i=0;
      foreach $x ($1, $2, $3, $4, $5, $6, $7, $8, $9) {
        $items{$keys[$i]} = &strip($x);
        $i++;
      }
    }
  }
  return %items;
}

sub q_make_select_into {
  my ($provider, $table, $top, $r_items) = @_;
  my  %items = %$r_items;
  my  %qs;

  $qs = $items{'select'}.' top '.$top.' '.$items{'args'}.' into '.$table.
              ' from '.$items{'from'}.' '.$items{'order'};

  return $qs and &strip($qs) or '';
}

sub q_make_drop_table {
  my ($provider, $database, $schema, $table) = @_;
  my  $qs = 'drop table '.$database.$schema.$table;

  if( !$provider || $provider eq 'mysql' ) {
    $qs = "drop table if exists ".$database.$schema.$table;
  } else {
    $qs = "drop table ".$database.$schema.$table;
  };
  return $qs;
}

sub q_make_delete_from_table {
  my ($provider, $database, $schema, $table, $where) = @_;
  my  $qs =
      'delete from '.$database.$schema.$table.
      ( $where ? ' where '.$where : '' );
  return $qs;
}

sub q_make_clone_table {
  my ($provider, $database, $schema, $table, $r_columns, $engine, $PK) = @_;
  my  @columns = @$r_columns;
  my  $attrs = '';
  my  $qs;

  $table = &strip($table);

  if( !$provider || $provider eq 'mysql' ) {
    $qs = "create table if not exists $database.$table (";
  } else {
    $qs = "create table $database.$schema.$table (";
  };
  if( $qs ) {
    foreach $r(@columns) {
      my %c = %$r;
      my $name = $c{'COLUMN_NAME'};
      my $primary_key = ( ($PK && uc($name) eq uc($PK)) ? ' primary key' : '' );
      my $type = &q_type($provider, $c{'TYPE_NAME'});
      my $size = &q_size($provider, $type, $c{'COLUMN_SIZE'});
      my $null = $c{'NULLABLE'} && 'null' || 'not null';
      $attrs .= ($attrs ? ', ' : '')."$name $type$size $null$primary_key";
    }
    $qs = $qs.$attrs.')';
  }
  if( $qs && $engine && $provider eq 'mysql' ) {
    $qs .= " engine $engine";
  }
  return $qs;
}

sub q_types_converter {
  my ($sth, $provider, $destination, $r_columns, $x_strip) = @_;
  my  @columns = @$r_columns;

  my $row = $sth->fetchrow_arrayref();

  if( defined $row ) {
    my $i = 0;

    foreach $r(@columns) {
      my %c = %$r;
      my $t = lc($c{'TYPE_NAME'});

      # conver *mssql* -> *mysql*
      if( $provider eq 'mssql' and $destination eq 'mysql' ) {
        if( $t eq 'bit' ) {
          $row->[$i] = ($row->[$i]) ? 1 : 0 unless undef;
        } elsif( $t eq 'smalldatetime' || $t eq 'datetime' ) {
          my $s = ''.$row->[$i];
          $s =~ s/(\d\d)\.(\d\d)\.(\d\d\d\d)\s*([\d\:]*?)/$3-$2-$1 $4/g;
          $row->[$i] = $s; #str2time($s);
        } elsif( $t eq 'timestamp' ) {
          $row->[$i] = undef;
        } elsif( $t eq 'varchar' ) {
          my $s = &txt_cleanup($row->[$i]);
          if( $x_strip ) {
             $s = &strip($s);
          }
          $row->[$i] = $s;
        #} elsif( $t eq 'text' ) {
          #$row->[$i] = &txt_cleanup($row->[$i]);
        }
      }

      # conver *mysql* -> *mssql*
      if( $provider eq 'mysql' and $destination eq 'mssql' ) {
        if( $t == 'bit' ) {
        } else {
        }
      }

      $i++;
    }
  }

  return $row;
}
#
# ------------------------------------------------------------------------------
#

return 1;