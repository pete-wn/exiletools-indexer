#!/usr/bin/perl

$|=1;

# Set required modules, these must all be installed!
use LWP::UserAgent;
use JSON;
use JSON::XS;
use Encode;
use utf8::all;
use Date::Parse;
use Time::HiRes qw(usleep);
use Search::Elasticsearch;
use Text::Unidecode;
use Data::Dumper;


# Load in external subroutines
require("subs/all.subroutines.pl");
require("subs/sub.formatJSON.pl");
&StartProcess;

# The following creates a realtime log file with basic JSON data
# that can be monitored by a third party instead of monitoring the entire
# stash stream.
#
# If you do not want to export a JSON log file, simply comment out
# the creation of the filehandle
open(our $JSONLOG, ">>", "$conf{baseDir}/logs/item-log.json") || die "FATAL: Unable to open json log!\n";
select((select($JSONLOG), $|=1)[0]);

# Some users may want to store source copies of the original river JSON data
# on disk. This allows you to re-build a live index from historical data, and
# is useful if a bug is found in the conversion, a new stat needs to be added,
# etc. If you do not want to store an on-disk copy, just comment out this line.
# Otherwise, make sure it is pointed at a valid location and the directory
# exists
$saveToDiskLocation = "$conf{baseDir}/riverData";


# The official Public Stash Tab API URL
our $apiURL = "http://www.pathofexile.com/api/public-stash-tabs";

# This is for testing
#our $apiURL = "http://localhost:8080/stash-api-test";

# Create a user agent
our $ua = LWP::UserAgent->new;
# Make sure it accepts gzip
our $can_accept = HTTP::Message::decodable;

# Nail up the Elastic Search connections
local $e = Search::Elasticsearch->new(
  cxn_pool => 'Sniff',
  cxn => 'Hijk',
  nodes =>  [
    "$conf{esHost}:9200",
    "$conf{esHost2}:9200",
    "$conf{esHost3}:9200"
  ],
  # enable this for debug but BE CAREFUL it will create huge log files super fast
#   trace_to => ['File','/tmp/eslog.txt'],

  # Huge request timeout for bulk indexing
  request_timeout => 300
);

local $itemBulk = $e->bulk_helper(
  index => "$conf{esItemIndex}",
  max_count => '5000',
  max_size => '0',
  type => "$conf{esItemType}",
);

local $stashTabStatsBulk = $e->bulk_helper(
  index => "$conf{esStatsIndex}",
  max_count => '5000',
  max_size => '0',
  type => "stashtab",
);


# On startup, check the stats index for the most recent run to start from that next_change_id
my $lastRun = $e->search(
  index => "$conf{esStatsIndex}",
  type => "run",
  body => {
    query => {
      match_all => {}
    },
    size => 1,
    sort => { "runTime" => { "order" => "desc" } }
  }
);

my $next_change_id = $lastRun->{hits}->{hits}->[0]->{_source}->{next_change_id} if ($lastRun->{hits}->{total} > 0);

# This variable will cause the system to continually re-run the river
# If any extreme errors occur in the subroutine, it should be cleared out
# which will abort the process
my $keepRunning = 1;

while($keepRunning) {
  my $status = &RunRiver("$next_change_id");
  if ($status eq "Maintenance") {
    &d("Maintenance message received on pathofexile.com, sleeping for 2 minutes!\n");
    sleep 120;
  } elsif ($status =~ /next_change_id:(.*?)$/) {
    $next_change_id = $1;
    sleep 1;
  } else {
    &d("FATAL ERROR: RunRiver did not return a valid status! \"$status\" Aborting!\n");
    die;
  }
}


&ExitProcess;

exit;


sub RunRiver {
  my $change_id = $_[0];
  my $fetchURL = $apiURL;
  my $runTime = time();

  # If a change id was specified, modify the URL
  if ($change_id) {
    $fetchURL = $apiURL."?id=$change_id";
# This is for testing
#    $fetchURL = $apiURL."/$change_id.json";
  }

  &d("! Processing API URL: $fetchURL\n");

  $t0 = [Time::HiRes::gettimeofday];
  my $response = $ua->get("$fetchURL",'Accept-Encoding' => $can_accept);
  my $content = $response->decoded_content;
  # Check for an error in the response code!!

  # Create a local hash for statistics data
  my %changeStats;
  $changeStats{TotalTransferBytes} += length($response->content);
  $changeStats{TotalUncompressedBytes} += length($response->decoded_content);




  # Check for Maintenance message
  if ($content =~ /pathofexile.com is currently down for maintenance. Please try again later/) {
    return("Maintenance");
  }

  # Remove funky <<set formatting
  $content =~ s/\<\<set:(\S+?)\>\>//g;

  # encode the JSON riverData into something perl can reference 
  $json = JSON::XS->new->utf8->pretty->allow_nonref;
  my %riverData = %{$json->decode($content)};
  $interval = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
  &d("! Downloaded and pre-processed as JSON in $interval seconds\n");

  $t0 = [Time::HiRes::gettimeofday];
  $t1 = [Time::HiRes::gettimeofday];

  # iterate the stashes
  foreach $stash (@{$riverData{stashes}}) {
    $changeStats{Stashes}++;

    # Fetch a current list of items in this stash in the index
    # set it to local to the formatJSON subroutine can see it
    local $currentStashData = $e->search(
      index => "$conf{esItemIndex}",
      type => "$conf{esItemType}",
      body => {
        query => {
          bool => {
            must => [
              { term => { "shop.stash.stashID" => $stash->{id} } },
              { term => { "shop.verified" => "YES" } }
            ]

          }
        },
        size => 500
      }
    );
    $itemSearchTime += $currentStashData->{took};
  
    my $itemCount = 0;
    my %itemStats;
    $itemStats{Added} = 0;
    $itemStats{Unchanged} = 0;
    $itemStats{Modified} = 0;

    foreach $item (@{$stash->{items}}) {
      $changeStats{TotalItems}++;
      $itemCount++;

      my ($jsonout,$uuid,$itemStatus) = &formatJSON($item, "$stash->{accountName}", "$stash->{id}", "$stash->{stash}", "$stash->{lastCharacterName}");
      $changeStats{"$itemStatus"}++;
      $itemStats{"$itemStatus"}++;
#      &sv(">>>> Processed: $stash->{accountName} | $stash->{id} | $stash->{stash} | $uuid\n");
      $itemBulk->index({ id => "$uuid", source => "$jsonout" });
    }

    # Anything left in the currentStashData array is gone, update the index appropriately
    my $goneCount = 0;
    foreach $scanItem (@{$currentStashData->{hits}->{hits}}) {
      if ($scanItem->{_source}->{uuid}) {
        $goneCount++;
        $changeStats{GoneItems}++;

        my $item = $scanItem->{_source}; 
        $item->{shop}->{modified} = time() * 1000;
        $item->{shop}->{updated} = time() * 1000;
        $item->{shop}->{verified} = "GONE";
        my $jsonout = JSON::XS->new->utf8->encode($item);
        $itemBulk->index({ id => "$item->{uuid}", source => "$jsonout" });
        &sv("i  Gone: $item->{shop}->{sellerAccount} | $item->{info}->{fullName} | $item->{uuid} | $item->{shop}->{amount} $item->{shop}->{currency}\n");

      }
    }

    &sv("% StashTab: $stash->{accountName} | $stash->{stash} | $stash->{id} | $itemCount Total Items | $itemStats{Added} Added | $itemStats{Modified} Modified | $itemStats{Unchanged} Unchanged | $goneCount GONE\n");
    # Add stash information to indexing stats index
    $stashTabStatsBulk->index({
      id => "$stash->{id}-$runTime",
      source => {
        stashID => "$stash->{id}-$runTime",
        accountName => $stash->{accountName},
        totalItems => $itemCount * 1,
        gone => $goneCount * 1,
        added => $itemStats{Added} * 1,
        modified => $itemStats{Modified} * 1,
        unchanged => $itemStats{Unchanged} * 1,
        stashId => $stash->{id},
        stashName => $stash->{stash},
        runTime => $runTime,
      }
    });

    # Display some stats on stash tab processing speed
#    if ($changeStats{Stashes} % 10 == 0) {
#      $interval = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
#      $intervalShort = Time::HiRes::tv_interval ( $t1, [Time::HiRes::gettimeofday]);
#      &sv("10 Stashes [$changeStats{Stashes} Total | $changeStats{TotalItems} Items] processed in $intervalShort [$interval] seconds | $itemSearchTime ms search time | $changeStats{GoneItems} Items Gone\n");
#      $t1 = [Time::HiRes::gettimeofday];
#      our $itemSearchTime = 0;
#    }
  }
#  &sv("Bulk Flushing\n");
  $itemBulk->flush;
  $stashTabStatsBulk->flush;
  
  if ($changeStats{Stashes} > 0) {
    $interval = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
    &d("* ThisChangeID: $changeStats{Stashes} Stashes | $changeStats{TotalItems} Total Items | $changeStats{GoneItems} Gone Items | $changeStats{TotalTransferBytes} bytes transferred | $changeStats{TotalUncompressedBytes} bytes uncompressed | ".sprintf("%.2f", $interval)." seconds | ".sprintf("%.2f",($changeStats{TotalItems} / $interval))." items/s | ".sprintf("%.2f", ($changeStats{Stashes} / $interval))." stashes/s\n");

    # Add Run information to the indexing stats index
    $e->index(
      index => "$conf{esStatsIndex}",
      type => "run",
      id => "$runTime",
      body => {
        uuid => "$runTime",
        runTime => $runTime,
        totalTransferKB => ($changeStats{TotalTransferBytes} / 1024) * 1,
        totalUncompressedTransferKB => ($changeStats{TotalUncompressedBytes} / 1024) * 1,
        totalStashes => $changeStats{Stashes} * 1,
        totalItems => $changeStats{TotalItems} * 1,
        change_id => $change_id,
        next_change_id => $riverData{next_change_id},
        secondsToComplete => $interval * 1,
        itemsPerSecond => ($changeStats{TotalItems} / $interval) * 1,
        stashesPerSecond => ($changeStats{Stashes} / $interval) * 1,
        itemsAdded => $changeStats{Added} * 1,
        itemsUnchanged => $changeStats{Unchanged} * 1,
        itemsModified => $changeStats{Modified} * 1,
        itemsGone => $changeStats{GoneItems} * 1
      }
    );
    # If saveToDiskLocation is set, let's store a copy of the data
    if (($saveToDiskLocation) && ($change_id)) {
      my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);                             
      my $yyyymmdd = sprintf "%.4d%.2d%.2d", $year+1900, $mon+1, $mday;
      unless (-d "$saveToDiskLocation/$yyyymmdd") {
        mkdir("$saveToDiskLocation/$yyyymmdd");
      }
      open(my $SAVERIVER, ">", "$saveToDiskLocation/$yyyymmdd/$change_id");
      print $SAVERIVER "$content";
      close($SAVERIVER);
    }

    # Save the next_change_id to disk
  } else {
    &d("! No changes found this id! Will retry.\n");
  }
#  &d("Next Change ID: $riverData{next_change_id}\n");

  if ($riverData{next_change_id}) {
    return("next_change_id:$riverData{next_change_id}");
  } else {
    return("ERROR no next_change_id found!");
  }

}

sub jsonLOG {
  return unless($JSONLOG);
  my $message = $_[0];
  print $JSONLOG "$message\n";
}
