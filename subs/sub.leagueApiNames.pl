#!/usr/bin/perl

use DBI;

# Create a hash of league short names vs API Names

$dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";
$statement = $dbh->prepare("SELECT * FROM `league-list`");
$statement->execute;
$statement->bind_columns(undef, \$myleague, \$prettyName, \$apiName, \$startTime, \$endTime, \$active, \$itemjsonName, \$archivedLadder, \$shopForumURL, \$shopURL, \$shopForumID);
while ($statement->fetch()) {
  $league{$myleague} = "$apiName";
  next unless ($active);
  $activeLeagues{$myleague}{apiName} = "$apiName";
  $activeLeagues{$myleague}{shopForumURL} = "$shopForumURL";
  $activeLeagues{$myleague}{shopForumID} = "$shopForumID";
}
$dbh->disconnect;

return true;
