#!/usr/bin/perl

# This script will update EVERY ITEM in the database with new chaosEquiv rates
# Use this if you have changed the chaosEquiv rates in sub.currencyValues.pl
#
# Note: You still need to index everything to ES after doing this, but inES
# will be set to no

use Search::Elasticsearch;
use DBI;
require("subs/all.subroutines.pl");
require("subs/sub.currencyValues.pl");

$dbh = DBI->connect("dbi:mysql:$conf{dbName}","$conf{dbUser}","$conf{dbPass}") || die "DBI Connection Error: $DBI::errstr\n";

print localtime()." Building Select Query\n";

#$query = "select `uuid`,`currency`,`amount` from `items` where `currency` != \"NONE\"";
# Exalted Orbs only
$query = "select `uuid`,`currency`,`amount` from `items` where `currency` = \"Exalted Orb\"";

$query_handle = $dbh->prepare($query);
$query_handle->{"mysql_use_result"} = 1;

print localtime()." Executing Select Query\n";

$query_handle->execute();

print localtime()." Binding Columns\n";
$query_handle->bind_columns(undef, \$uuid, \$currency, \$amount);

print localtime()." Fetching & Updating...\n";
while($query_handle->fetch()) {
  my $chaosEquiv = &StandardizeCurrency("$amount","$currency");  

  $updateHash{"$uuid"} = $chaosEquiv;  

  $count++;
  if ($count % 5000 == 0) {
    print localtime()." $count rows found\n";
  }
}

print localtime()." $count rows found for update\n";

foreach $uuid (keys(%updateHash)) {
  $dbh->do("UPDATE \`items\` SET
            chaosEquiv=\"$updateHash{$uuid}\",
            inES=\"no\"
            WHERE uuid=\"$uuid\"
            ") || die "SQL ERROR: $DBI::errstr\n";
  $updated++;
  if ($updated % 5000 == 0) {
    print localtime()." $updated rows updated in db\n";
  }
}




$dbh->disconnect;
