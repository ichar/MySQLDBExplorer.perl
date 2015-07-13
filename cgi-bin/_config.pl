#!C:/Perl/bin/perl

# Общие установки базы данных --------------------------------------------------
my $default_provider  = 'mssql';

# MS SQL Server
my $mssql_database    = 'master';     # Имя корневой базы данных
my $mssql_charset     = 'cp1251';     # Кодировка
my $mssql_host        = 'localhost';  # Имя хоста сервера баз данных
my $mssql_port        = '1433';       # Порт
my $mssql_user        = '';           # Имя пользователя
my $mssql_passwd      = '';           # Пароль

# MySQL
my $mysql_database    = 'mysql';      # Имя корневой базы данных
my $mysql_charset     = 'koi8r';      # Кодировка
my $mysql_host        = 'localhost';  # Имя хоста сервера баз данных
my $mysql_port        = '3306';       # Порт
my $mysql_user        = '';           # Имя пользователя
my $mysql_passwd      = '';           # Пароль

# Параметры, связанные с кодировкой клиента ------------------------------------
my $set_charset       = 1;

# Подпрограмма подключения к базе данных ---------------------------------------
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

    # соединение с базой данных
    $dbh = DBI->connect(
      "DBI:mysql:$database:$host:$port", $user, $passwd,
     {'RaiseError' => 1, 'AutoCommit' => 0}
    ) or die $DBI::errstr;
    # кодировка клиента
    $dbh->do("SET NAMES '$charset'")
      if( $charset ne '' && $set_charset == 1 );
  }
  return $dbh;
}

# Подпрограмма отключения от базы данных ---------------------------------------
sub db_close {
  my $dbh = shift;
  $dbh->disconnect() if($dbh);
}

return 1;