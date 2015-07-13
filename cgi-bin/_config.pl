#!C:/Perl/bin/perl

# ����� ��������� ���� ������ --------------------------------------------------
my $default_provider  = 'mssql';

# MS SQL Server
my $mssql_database    = 'master';     # ��� �������� ���� ������
my $mssql_charset     = 'cp1251';     # ���������
my $mssql_host        = 'localhost';  # ��� ����� ������� ��� ������
my $mssql_port        = '1433';       # ����
my $mssql_user        = '';           # ��� ������������
my $mssql_passwd      = '';           # ������

# MySQL
my $mysql_database    = 'mysql';      # ��� �������� ���� ������
my $mysql_charset     = 'koi8r';      # ���������
my $mysql_host        = 'localhost';  # ��� ����� ������� ��� ������
my $mysql_port        = '3306';       # ����
my $mysql_user        = '';           # ��� ������������
my $mysql_passwd      = '';           # ������

# ���������, ��������� � ���������� ������� ------------------------------------
my $set_charset       = 1;

# ������������ ����������� � ���� ������ ---------------------------------------
sub db_connect {
  my $n = scalar @_;
  my $provider = $n >= 1 && $_[0] || $default_provider;
  my $database;
  my $charset;
  my $host;
  my $port;
  my $user;
  my $passwd;
  my $dbh;

  if( $provider eq 'mssql' )
  {
    $database = $n >= 2 && $_[1] || $mssql_database;
    $charset  = $n >= 3 && $_[2] || $mssql_charset;
    $host     = $n >= 4 && $_[3] || $mssql_host;
    $port     = $n >= 5 && $_[4] || $mssql_port;
    $user     = $n >= 6 && $_[5] || $mssql_user;
    $passwd   = $n >= 7 && $_[6] || $mssql_passwd;

    $dbh = DBI->connect(
      "dbi:ADO:Provider=SQLOLEDB.1;Integrated Security=SSPI;Persist Security Info=False;".
      "Initial Catalog=$database;Data Source=$host", $user, $passwd,
     {'RaiseError' => 1, 'AutoCommit' => 0}
    ) or die $DBI::errstr;
  }
  else
  {
    $database = $n >= 2 && $_[1] || $mysql_database;
    $charset  = $n >= 3 && $_[2] || $mysql_charset;
    $host     = $n >= 4 && $_[3] || $mysql_host;
    $port     = $n >= 5 && $_[4] || $mysql_port;
    $user     = $n >= 6 && $_[5] || $mysql_user;
    $passwd   = $n >= 7 && $_[6] || $mysql_passwd;

    # ���������� � ����� ������
    $dbh = DBI->connect(
      "DBI:mysql:$database:$host:$port", $user, $passwd,
     {'RaiseError' => 1, 'AutoCommit' => 0}
    ) or die $DBI::errstr;
    # ��������� �������
    $dbh->do("SET NAMES '$charset'")
      if( $charset ne '' && $set_charset == 1 );
  }
  return $dbh;
}

# ������������ ���������� �� ���� ������ ---------------------------------------
sub db_close {
  my $dbh = shift;
  $dbh->disconnect() if($dbh);
}

return 1;