#!/usr/bin/perl

# This script is a CONSUMER of the official GG Public Stash Tab API that also
# PRODUCES this data to a local kafka partition for processing.
#
# It's only job is to pull the latest changes from GGG, perform very minor
# modifications of the JSON data to embed additional information, then add
# this data to a kafka topic for processing by other programs.
#
# The main reason to have this run as a separate task is to allow asynchronous
# processing of the feed, i.e. old data can be processed from GGG while new
# data is being downloaded.

$|=1;

# Set required modules, these must all be installed!
use LWP::UserAgent;
use JSON::XS;
use Encode;
use utf8::all;
use Date::Parse;
use Time::HiRes qw(usleep);
use Text::Unidecode;
use Data::Dumper;
use File::Slurp;
use Storable;
use Scalar::Util qw( blessed);
use Try::Tiny;
use Kafka qw( $BITS64);
use Kafka::Connection;
use Kafka::Producer;
use Kafka::Consumer;
use String::Random qw(random_string);
use Search::Elasticsearch;

our $totalProcessingTime;
our $totalUpdates;

# This ensures we capture a ^c and exit gracefully
$SIG{INT} = \&catch_int;
sub catch_int {
  &d("!!! [$$] Caught SIGINT, exiting...\n");
  &d("Performance: $totalUpdates processed in $totalProcessingTime seconds (".($totalProcessingTime / $totalUpdates)." sec / update)\n");
  undef $consumer;
  undef $producer;
  undef $connection;  
  &ExitProcess;
  exit 3;
}

# Load in external subroutines
require("subs/all.subroutines.pl");
&StartProcess;

# Connect to Kafka and catch any errors
my ( $connection, $producer );
try {
    $connection = Kafka::Connection->new( host => 'localhost' );
    $producer = Kafka::Producer->new( Connection => $connection );
} catch {
    my $error = $_;
    if ( blessed( $error ) && $error->isa( 'Kafka::Exception' ) ) {
        warn 'Error: (', $error->code, ') ',  $error->message, "\n";
        exit;
    } else {
        die $error;
    }
};
 

# The official Public Stash Tab API URL
our $apiURL = "http://www.pathofexile.com/api/public-stash-tabs";

# This adds support to serialize data from a file source instead of the web API for
# more efficient benchmarking using repeatable data. To use this, you must have
# a flatfile history of API data.
if ($args{usefiles}) {
  $srcFileDir = "/pwxdata/poe/stashtabs/riverData/20160321";
  $next_change_id = "2198709-2322115-2167158-2546114-2419716";
  our $changeIDLog = "$logDir/offset/next_change_id.log";
} else {
  # For normal operation, we need to log change ids. Previously this was done
  # by querying the ES index, but now we're just going to keep a simple
  # log file with this data.
  our $changeIDLog = "$logDir/offset/next_change_id.log";
  if (-f "$changeIDLog") {
    $next_change_id = read_file("$changeIDLog"); 
  }
  $next_change_id = "0" unless ($next_change_id =~ /^\d+/);
}

# Create a user agent
our $ua = LWP::UserAgent->new;
# Make sure it accepts gzip
our $can_accept = HTTP::Message::decodable;

# Connect to Elasticsearch
&connectElastic;

# Set this up to run forever
my $keepRunning = 1;

while($keepRunning) {
  $kr0 = [Time::HiRes::gettimeofday];
  my $status = &RunRiver("$next_change_id");
  if ($status eq "Maintenance") {
    # If this matches, then path ofexile.com is down for maintenance and we shouldn't spam them
    &d("Maintenance message received on pathofexile.com, sleeping for 2 minutes!\n");
    sleep 120;
  } elsif ($status =~ /^Failed/) {
    # If this happens, we got an HTTP error of some kind and that means the API is busted or overloaded, so no spamming
    &d("Web Server Error: $status | Sleeping for 2 minutes!\n");
    sleep 120;
  } elsif ($status =~ /next_change_id:(.*?)$/) {
    # We got a valid next_change_id, so we're going to wait 1s then grab it
    $next_change_id = $1;

    # Write this information out to $changeIDLog
    open(my $CHANGEIDLOG, ">", $changeIDLog) || die "FATAL: Unable to open changeIDLog $changeIDLog - $!\n";
    print $CHANGEIDLOG $next_change_id;
    close($CHANGEIDLOG);

    # Sleep for 1 second then repeat
    #usleep 500000;
    sleep 3;
  } else {
    &d("WARNING: RunRiver did not return a valid status! \"$status\" Re-trying with old change id in 5s!\n");
    sleep 5;
  }
  $interval = Time::HiRes::tv_interval ( $kr0, [Time::HiRes::gettimeofday]);
  &d("\$ Full update consumed in $interval seconds\n");

  # This code is only for benchmarking and allows me to limit execution. IT SHOULD BE COMMENTED OUT IN PRODUCTION
  # BEGIN BENCHMARK CODE
#  if ($totalUpdates == 500) {
#    &d("Performance: $totalUpdates processed in $totalProcessingTime seconds (".($totalProcessingTime / $totalUpdates)." sec / update)\n");
#    &ExitProcess;
#  }
  # END BENCHMARK CODE
}

# Cleanly disconnect in case somehow we abort the loop
undef $consumer;
undef $producer;
$connection->close;
undef $connection;
&ExitProcess;
exit;

sub RunRiver {
  my $change_id = $_[0];
  my $fetchURL = $apiURL;
  my $runTime = time();
  my $content;
  my %changeStats;

  $t0 = [Time::HiRes::gettimeofday];

  if ($args{usefiles}) {
    $content = read_file("$srcFileDir/$change_id");    
  } else {
    # If a change id was specified, modify the URL
    if ($change_id) {
      $fetchURL = $apiURL."?id=$change_id";
    }
  
    &d("! Processing API URL: $fetchURL\n");
  
    my $response = $ua->get("$fetchURL",'Accept-Encoding' => $can_accept);
    unless ($response->is_success) {
      return("Failed: ".$response->status_line);
    }
    $content = $response->decoded_content;
    # Check for an error in the response code!!
  
    $changeStats{TotalTransferBytes} += length($response->content);
    $changeStats{TotalUncompressedBytes} += length($response->decoded_content);
  }
  # Check for Maintenance message
  if ($content =~ /pathofexile.com is currently down for maintenance. Please try again later/) {
    return("Maintenance");
  }
  $interval = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
  &d(". [$change_id] Downloaded ".sprintf("%.2f", $changeStats{TotalTransferBytes} / 1024 / 1024)."MB of compressed JSON (".sprintf("%.2f", $changeStats{TotalUncompressedBytes} / 1024 / 1024)."MB raw) in $interval seconds (".sprintf("%.2f", $changeStats{TotalTransferBytes} / 1024 / $interval)."KB/s)\n");

  $t0 = [Time::HiRes::gettimeofday];

  # Remove funky <<set formatting
  $content =~ s/\<\<set:(\S+?)\>\>//g;

  # encode the JSON riverData into something perl can reference 
  my %riverData = %{JSON::XS->new->utf8->allow_nonref->decode($content)};
  # All done and loaded into a perl hash for processing. Booya.

  if ($riverData{error}{message}) {
    return("ERROR: API returned an error: \"$riverData{error}{message}\"");
  }

  # Get a timestamp of this data that was fetched
  my $fetchTime = time();

  foreach $stash (@{$riverData{stashes}}) {
    # Keep track of how many stashes we saw in this change
    $changeStats{Stashes}++;

    # Embed the timestamp data into this stash's JSON data
    $stash->{fetchTime} = $fetchTime;

    # Encode as JSON
    my $jsonout = JSON::XS->new->utf8->encode($stash);

    # Some random testing / debug stuff
    if ($stash->{id} eq "cf9ac82d7e535c65e1842c84c4a0a9d46b8ced6ba1b558176712f1f14f2e3706") {
      print "----------\nMatching Stash Found:\n----------\n$jsonout\n----------\n";
    }

    my $partition;
    if ($conf{kafkaTopicPartitionsIncoming} > 1) {
      $partition = int(rand($conf{kafkaTopicPartitionsIncoming}));
    } else {
      $partition = 0;
    }

    # Send this data to the appropriate partition
    $producer->send(
        $conf{kafkaTopicNameIncoming},
        $partition,
        $jsonout
    );
  }

  if ($changeStats{Stashes} > 0) {
    $interval = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
    $totalProcessingTime += $interval;
    $totalUpdates++;

    my $runuuid = $runTime;
    $runuuid .= random_string("ccccc");
    # Index this information into Elasticsearch
    $e->index(
      index => "$conf{esStatsIndex}",
      type => "run",
      id => "$runTime",
      body => {
        uuid => "$runuuid",
        runTime => $runTime,
        totalTransferKB => ($changeStats{TotalTransferBytes} / 1024) * 1,
        totalUncompressedTransferKB => ($changeStats{TotalUncompressedBytes} / 1024) * 1,
        totalStashes => $changeStats{Stashes} * 1,
        change_id => $change_id,
        next_change_id => $riverData{next_change_id},
        secondsToComplete => $interval * 1,
        stashesPerSecond => ($changeStats{Stashes} / $interval) * 1,
      }
    );

    $interval = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
    &d(". [$change_id] Added $changeStats{Stashes} stashes to Kafka and indexed stats for $runuuid to Elasticsearch in $interval seconds\n");
  }

  if ($riverData{next_change_id}) {
    return("next_change_id:$riverData{next_change_id}");
  } else {
    return("No next_change_id found!");
  }

}


sub connectElastic {
  # Nail up the Elastic Search connections to post indexing stats
  our $e = Search::Elasticsearch->new(
    cxn_pool => 'Sniff',
    cxn => 'Hijk',
    nodes =>  [
      "$conf{esHost}:9200"
    ],
    # enable this for debug but BE CAREFUL it will create huge log files super fast
  #   trace_to => ['File','/tmp/eslog.txt'],

    # Huge request timeout for bulk indexing
    request_timeout => 180
  );
}
