#!/usr/bin/perl

use DBI;


# Create a hash of league short names vs API Names

$dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";
%leagueHash = %{$dbh->selectall_hashref("select * from (`league-list`)","league")};
$dbh->disconnect;

return true;
