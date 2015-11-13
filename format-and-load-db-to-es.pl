#!/usr/bin/perl

use Search::Elasticsearch;
use DBI;
use JSON;
use JSON::XS;
use Encode;
use Data::Dumper;
use Time::HiRes;
use Parallel::ForkManager;
use utf8;
use Text::Unidecode;
require("subs/all.subroutines.pl");
require("subs/sub.formatJSON.pl");

# TO DO STUFF:
#
# identify unidentified uniques?

# == Initial Options 
# Whether or not to give basic debug output
$debug = 1;

# Whether or not to give SUPER VERBOSE output. USE WITH CARE! Will create huge logs
# and tons of spammy text.
$sv = 0;

# The number of processes to fork
$forkMe = 1;

# == Initial Startup
&StartProcess;

$dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}") || die "DBI Connection Error: $DBI::errstr\n";

# Access the database to build a lookup table of threadid information so that we don't waste
# time pulling this on an item-by-item basis.

&d("Building Thread/Account Lookup Table...\n");
my %sellerHash = %{$dbh->selectall_hashref("select `threadid`,`sellerAccount`,`sellerIGN`,`generatedWith`,`threadTitle` FROM `thread-last-update`","threadid")};


# The base query feeding this process will vary depending on the arguments given on the
# command line. Valid arguments currently include:
#   full - does a full update of everything
#   ###### - where ##### is an epoch timestamp, pulls all items newer than this
if ($ARGV[0] eq "full") {
  &d("!! WARNING: FULL UPDATE SPECIFIED! All previously indexed items will be scanned and re-indexed.\n");
  print localtime()." Selecting items from items\n";
  $pquery = "select `uuid` from `items` where `inES`=\"yes\"";
  $cquery = "select count(`uuid`) from `items` where `inES`=\"yes\"";
} elsif ($ARGV[0]) {
  $pquery = "select `uuid` from `items` where `updated`>$ARGV[0]";
  $cquery = "select count(`uuid`) from `items` where `updated`>$ARGV[0]";
} else {
  $pquery = "select `uuid` from `items` where `inES`=\"no\"";
  $cquery = "select count(`uuid`) from `items` where `inES`=\"no\"";
}

# Get a count of how many items we will process
my $updateCount = $dbh->selectrow_array("$cquery");

if ($updateCount < 1) {
  &d("!! No new uuid's to process! Aborting run.\n");
  $dbh->disconnect;
  &ExitProcess;
}

# If this is a small update, override the number of forks to something that isn't wasteful
# (we shouldn't be processing less than 10k items per fork
my $maxForkCheck = int($updateCount / 10000) + 1;

if ($maxForkCheck < $forkMe) {
  $forkMe = $maxForkCheck;
  &d(" > Overriding forks of threads to a max of $forkMe as update is small!\n");
}

# This is a little weird/clumsy. Basically, we are going to create a hash of uuid's for each
# fork to process, with the total number split across all the forks. So, to start with, we take
# the total number of items to be updated and divide them by the number of forks to see the max
# uuid's each fork should process.
$maxInHash = int($updateCount / $forkMe) + 1;

&d(" > $updateCount uuid's to be updated [$forkMe fork(s), $maxInHash per fork]\n");

$t0 = [Time::HiRes::gettimeofday];
&d("Preparing update hash:\n");
$query_handle=$dbh->prepare($pquery);
$query_handle->{"mysql_use_result"} = 1;
$query_handle->execute();
$query_handle->bind_columns(undef, \$uuid);

# Keeps track of our active fork ID's
$forkID = 1;
# For tracking our iterations through the query
my $ucount = 0;

# Basically, iterate through the select by uuid, and add all uuid's to a hash table for
# the forkID until the count exceeds maxInHash, then increment the forkID
while($query_handle->fetch()) {
  $ucount++;
  if ($ucount > $maxInHash) {
    $forkID++;
    $ucount = 0;
  }
  $uhash{"$forkID"}{"$uuid"} = 1;
}

$dbh->disconnect;
$endelapsed = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
&d(" > Update hash built in $endelapsed seconds.\n");

# Prepare forkmanager
my $manager = new Parallel::ForkManager( $forkMe );
&d("Processing started! This may take awhile...\n");

# For each forkID in our hash of UUID's, fork a process and go!
foreach $forkID (keys(%uhash)) {

  $manager->start and next;
  $dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}") || die "DBI Connection Error: $DBI::errstr\n";

  my $e = Search::Elasticsearch->new(
    cxn_pool => 'Sniff',
    nodes =>  [
      "$conf{eshost}:9200",
      "$conf{eshost2}:9200"
    ],
    trace_to => ['File','/tmp/eslog.txt'],
    # Huge request timeout for bulk indexing
    request_timeout => 300
  );

  die "some error?"  unless ($e);
  
  my $bulk = $e->bulk_helper(
    index => "$conf{esindex}",
    max_count => '5100',
    max_size => '0',
    type => "$conf{estype}",
  );

  $t0 = [Time::HiRes::gettimeofday];

  foreach $uuid (keys(%{$uhash{$forkID}})) {
    my @datarow = $dbh->selectrow_array("select * from `items` where `uuid`=\"$uuid\" limit 1");
    my $uuid = $datarow[0];
    my $threadid = $datarow[1];
    my $md5sum = $datarow[2];
    my $added = $datarow[3];
    my $updated = $datarow[4];
    my $modified = $datarow[5];
    my $currency = $datarow[6];
    my $amount = $datarow[7];
    my $verified = $datarow[8];
    my $priceChanges = $datarow[9];
    my $lastUpdateDB = $datarow[10];
    my $chaosEquiv = $datarow[11];
    my $inES = $datarow[12];

    $count++;
    no autovivification;
    local %item;

    if ($sellerHash{$threadid}{threadTitle}) {
      $item{shop}{threadTitle} = $sellerHash{$threadid}{threadTitle};
    } else {
      my $threadTitle = $dbh->selectrow_array("select `title` from `web-post-track` where `threadid`=\"$threadid\"");
      if ($threadTitle) {
        $item{shop}{threadTitle} = $threadTitle;
      } else {
        $item{shop}{threadTitle} = "Unknown";
      } 
    }
    # Decode unicode in threadTitle
    $item{shop}{threadTitle} = unidecode($item{shop}{threadTitle});

    $item{uuid} = $uuid;
    $item{md5sum} = $md5sum;
    $item{shop}{threadid} = "$threadid";
    $item{shop}{added} += $added * 1000;
    $item{shop}{updated} += $updated * 1000;
    $item{shop}{modified} += $modified * 1000;
    $item{shop}{currency} = $currency;
    $item{shop}{amount} += $amount;
    $item{shop}{verified} = $verified;
    $item{shop}{priceChanges} += $priceChanges;
    $item{shop}{lastUpdateDB} = $lastUpdateDB;
    $item{shop}{chaosEquiv} += $chaosEquiv;
    $item{shop}{sellerAccount} = $sellerHash{$threadid}{sellerAccount};
    $item{shop}{sellerIGN} = $sellerHash{$threadid}{sellerIGN};
    $item{shop}{generatedWith} = $sellerHash{$threadid}{generatedWith} if ($sellerHash{$threadid}{generatedWith});

    my $rawjson = $dbh->selectrow_array("select `data` from `raw-json` where `md5sum`=\"$md5sum\" limit 1");
    unless ($rawjson) {
      print "[$forkID] WARNING: $md5sum returned no data from raw json db!\n";
      next;
    }
    my $jsonout = &formatJSON("$rawjson");

  # Some debugging stuff 
  # Pretty Version Output
#    my $jsonchunk = JSON->new->utf8;
#    my $prettychunk = $jsonchunk->pretty->encode(\%item);
#    print "$prettychunk\n";
#    last if ($count > 5);
  
    $bulk->index({ id => "$uuid", source => "$jsonout" });
    push @changeFlagInDB, "$uuid";
 
    # We go ahead and bulk flush then update the DB at 5000 manually so we can give some output
    # for anyone watching 
    if ($count % 5000 == 0) {
      &sv("[$forkID] [$count] Bulk Flushing Data to Elastic Search:\n");
      $bulk->flush;
      &sv("[$forkID] [$count] -> Bulk Flush Completed\n");
      &sv("[$forkID] [$count]  Marking items as imported in DB:\n");
      foreach $updateuuid (@changeFlagInDB) {
        $dbh->do("UPDATE \`items\` SET inES=\"yes\" WHERE uuid=\"$updateuuid\"");
      }
      &sv("[$forkID] [$count] -> Database update completed...\n");
      $endelapsed = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
      &d("[$forkID] [$count] Bulk Processed in $endelapsed seconds\n");
      $t0 = [Time::HiRes::gettimeofday];
      undef @changeFlagInDB;
    }
  
  }

  # Flush the leftover items - I'm lazy and just copy/pasted, should probably make this a subroutine 
  &sv("[$forkID] [$count] Bulk Flushing Data to Elastic Search:\n"); 
  $bulk->flush;
  &sv("[$forkID] [$count] -> Bulk Flush Completed\n");
  &sv("[$forkID] [$count]  Marking items as imported in DB:\n");
  foreach $updateuuid (@changeFlagInDB) {
    $dbh->do("UPDATE \`items\` SET inES=\"yes\" WHERE uuid=\"$updateuuid\"");
  }
  &sv("[$forkID] [$count] -> Database update completed...\n");
  $endelapsed = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
  &d("[$forkID] [$count] Bulk Processed in $endelapsed seconds\n");
  undef @changeFlagInDB;
  
  &d("[$forkID] Elastic Search import complete!\n");
  
  $dbh->disconnect;
  $manager->finish;
}
$manager->wait_all_children;
&d("All processing children have completed their work!\n");

# == Exit cleanly
&ExitProcess;
