#!C:/Perl/bin/perl

print "Content-Type: text/html\n\n";

print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n\n";
print "<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"ru\" xml:lang=\"ru\">\n\n";
print "<head>\n";
print "<title>Переменные окружения</title>\n";
print "</head>\n\n";
print "<body>\n";
print "<h1>Переменные окружения</h1>\n";

foreach $element(sort(keys(%ENV)))
{
  print "<p>$element = $ENV{$element}</p>\n";
}

print "</body>\n\n";
print "</html>";

exit(0);