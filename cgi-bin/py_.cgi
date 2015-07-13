#!C:\Python24\python

import MySQLdb

print "Content-Type: text/html\n"
print "<html><head><title>Deshevle Classes through Python</title></head>"
print "<body>"
print "<h1>Classes of products</h1>"
print "<ul>"

connection = MySQLdb.connect(user='root', passwd='', db='deshevle')
connection.query('set names cp1251')
cursor = connection.cursor()
#cursor.execute("SELECT ID, code, title FROM classes LIMIT 10")
cursor.execute("SELECT ID, code, title FROM pd LIMIT 20")

for row in cursor.fetchall():
    print "<li><span style=\"font-family:verdana;font-size:11px\">%s code->(%s): %s</span></li>" % (row[0], row[1], row[2])

print "</ul>"
print "</body></html>"

connection.close()
