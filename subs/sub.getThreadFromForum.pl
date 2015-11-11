#!/usr/bin/perl

use utf8::all;

sub FetchShopPage {
  local $threadid = $_[0];
  my $targeturl = "http://www.pathofexile.com/forum/view-thread/$threadid";
  &d(">> FetchShopPage: (PID: $$) [$forumName] $targeturl\n");

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
    &d(">> FetchShopPage: (PID: $$) [$forumName] WARNING: HTTP Error Received: ".$response->decoded_content." Aborting request!\n");
    $stats{Errors}++;
    return("fail");
  }

  # Take the raw HTML and dump it to a file for later parsing
  mkpath("$conf{datadir}/$threadid/raw") unless (-d "$conf{datadir}/$threadid/raw");
  open(RAW, ">$conf{datadir}/$threadid/raw/$timestamp.html") || die "ERROR opening $conf{datadir}/$threadid/raw/$timestamp.html - $1\n";
  print RAW $content;
  close(RAW);

  # Prepare some local variables
  my $nojsonfound;

  # Extract the raw item JSON data from the javascript in the HTML
  if ($content =~ /require\(\[\"PoE\/Item\/DeferredItemRenderer\"\], function\(R\) \{ \(new R\((.*?)\)\)\.run\(\)\; \}\)\;/) {
    $rawjson = $1;
  } else {
    &d(">>> FetchShopPage: (PID: $$) [$forumName]  WARNING: No JSON found in $threadid\n");
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
  return if ($nojsonfound);
  &ProcessUpdate("$content","$rawjson");
  
  # Go ahead and mark this as processed in the queue
  $dbhf->do("UPDATE `shop-queue` SET
                 processed=\"2\"
                 WHERE `threadid`=\"$threadid\" AND `timestamp`=\"$timestamp\"
                 ") || die "SQL ERROR: $DBI::errstr\n";
}

return true;
