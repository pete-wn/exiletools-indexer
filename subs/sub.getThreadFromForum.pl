#!/usr/bin/perl

use utf8::all;

sub FetchShopPage {
  local $threadid = $_[0];
  local $forumID = $_[1];
  my $targeturl = "http://www.pathofexile.com/forum/view-thread/$threadid";
  &sv(">> FetchShopPage: (PID: $$) [$forumName($forumID)] $targeturl\n");

  # =========================================
  # Saving local copy of data
  local $timestamp = time();
  my $response = $ua->get("$targeturl",'Accept-Encoding' => $can_accept);
  $stats{TotalRequests}++;
  $stats{TotalTransferBytes} += length($response->content);
  $stats{TotalUncompressedBytes} += length($response->decoded_content);
  $stats{ShopPagesFetched}++;
  my $content = $response->decoded_content;

  # Return with an error if the content is bad
  unless ($response->is_success) {
    if ($response->decoded_content =~ /The resource you are looking for does not exist or has been removed/) {
      &d(">> FetchShopPage: (PID: $$) [$forumName($forumID)] [$targeturl] WARNING: This thread has been REMOVED!\n");
      $stats{Errors}++;
      return("Removed");
    } else {
      &d(">> FetchShopPage: (PID: $$) [$forumName($forumID)] [$targeturl] WARNING: HTTP Error Received: ".$response->decoded_content." Aborting request!\n");
      $stats{Errors}++;
      return("http error");
    }
  }

  # Take the raw HTML and dump it to a file for later parsing
  mkpath("$conf{dataDir}/$threadid/raw") unless (-d "$conf{dataDir}/$threadid/raw");
  open(RAW, ">$conf{dataDir}/$threadid/raw/$timestamp.html") || die "ERROR opening $conf{dataDir}/$threadid/raw/$timestamp.html - $1\n";
  print RAW $content;
  close(RAW);

  # Prepare some local variables
  my $nojsonfound;

  # Extract the raw item JSON data from the javascript in the HTML
  if ($content =~ /require\(\[\"PoE\/Item\/DeferredItemRenderer\"\], function\(R\) \{ \(new R\((.*?)\)\)\.run\(\)\; \}\)\;/) {
    $rawjson = $1;
  } else {
    &sv(">>> FetchShopPage: (PID: $$) [$forumName($forumID)]  WARNING: No JSON found in $threadid\n");
    $nojsonfound = 1;
  }
  my $processed;
  if ($nojsonfound > 0) {
    # No JSON means we don't need to process it, so we set processed to 5 to indicate it will never be touched by the processor
    $processed = "5";
  } else {
    # If we have JSON, setting the processed to 0 ensures it will be loaded by the queue
    $processed = "0";
  }

  # NOTE: This queuing system allows us to separate out forum gets from loading data
  # as of 2015/11/10 we are going to start processing the queue immediately from the
  # data in memory, but we're still saving a copy and monitoring the queue for record
  # keeping - this allows me to re-run the queue if needed without having to scan the
  # filesystem for html files.
 
  # Add information on this thread to the processing queue db table
  $dbhf->do("INSERT INTO `shop-queue` SET
            `threadid`=\"$threadid\",
            `timestamp`=\"$timestamp\",
            `processed`=\"$processed\",
            `forumid`=\"$forumID\",
            `nojsonfound`=\"$nojsonfound\",
            `origin`=\"$process\"
            ") || die "FATAL DBI ERROR: $DBI::errstr\n";

  # Done saving local copy of data
  # =========================================

  # Begin processing the data directly:
  if ($nojsonfound) {
    &UpdateThreadTables;
    return;
  }
  &ProcessUpdate("$content","$rawjson","$forumID");
  
  # Go ahead and mark this as processed in the queue
  $dbhf->do("UPDATE `shop-queue` SET
                 processed=\"2\"
                 WHERE `threadid`=\"$threadid\" AND `timestamp`=\"$timestamp\"
                 ") || die "SQL ERROR: $DBI::errstr\n";
}

sub OutputRunStats {

  # Output some stats for this fork
  $stats{TotalTransferKB} = int($stats{TotalTransferBytes} / 1024);
  $stats{TotalUncompressedKB} = int($stats{TotalUncompressedBytes} / 1024);
  foreach $stat (sort(keys(%stats))) {
    &d("STATS: (PID: $$) [$forum] $stat: $stats{$stat}\n");
  }

  use Search::Elasticsearch;

  my $e = Search::Elasticsearch->new(
    cxn_pool => 'Sniff',
    nodes =>  [
      "$conf{esHost}:9200",
      "$conf{esHost2}:9200"
    ],
    # enable this for debug but BE CAREFUL it will create huge log files super fast
    # trace_to => ['File','/tmp/eslog.txt'],
  
    # Huge request timeout for bulk indexing
    request_timeout => 300
  );

  die "some error?"  unless ($e);

  # Calculate the run time 
  my $runTime = (time() - $runStartTime);

  my $timestamp = time();
  
  # Create the ES JSON data
  my %fetchData;
  $fetchData{RunTimestamp} = $timestamp;
  $fetchData{Forum} = $forum;
  $fetchData{TotalRequests} += $stats{TotalRequests};
  $fetchData{TotalTransferKB} += $stats{TotalTransferKB};
  $fetchData{TotalUncompressedKB} += $stats{TotalUncompressedKB};
  $fetchData{ForumIndexPagesFetched} += $stats{ForumIndexPagesFetched};
  $fetchData{ShopPagesFetched} += $stats{ShopPagesFetched};
  $fetchData{Errors} += $stats{Errors};
  $fetchData{RunType} = $runType;
  $fetchData{NewThreads} += $stats{NewThreads};
  $fetchData{UnchangedThreads} += $stats{UnchangedThreads};
  $fetchData{UpdatedThreads} += $stats{UpdatedThreads};
  $fetchData{RunTime} += $runTime;
  my $fetchDataJSON = JSON::XS->new->utf8->encode(\%fetchData);

  # Insert stats for this fork into ES
  $e->index(
    index => "$conf{esStatsIndex}",
    type => "$conf{esRunStatsType}",
    body => "$fetchDataJSON" 
  );
  
  return;
}

return true;
