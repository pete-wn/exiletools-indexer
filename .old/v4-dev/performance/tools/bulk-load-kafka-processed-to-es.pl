#!/usr/bin/perl

use JSON::XS;
use Encode;
use utf8::all;
use Time::HiRes qw(usleep);
use Search::Elasticsearch;
use File::Slurp;
use Scalar::Util qw( blessed);
use Try::Tiny;
use Kafka qw( $BITS64 $DEFAULT_MAX_BYTES $DEFAULT_MAX_NUMBER_OF_OFFSETS $RECEIVE_EARLIEST_OFFSETS);
use Kafka::Connection;
use Kafka::Producer;
use Kafka::Consumer;

# This ensures we capture a ^c and exit gracefully
$SIG{INT} = \&catch_int;
sub catch_int {
  &d("!!! [$$] Caught SIGINT, exiting...\n");
  undef $consumer;                                                                                                                             
  undef $connection;  
  if ($args{benchmark}) {
    $interval = Time::HiRes::tv_interval ( $bencht0, [Time::HiRes::gettimeofday]);
    print "Processed $benchTotalItems in $interval seconds (".sprintf("%.2f", $benchTotalItems / $interval)." items/s)\n";

  }
  &ExitProcess;
  exit 3;
}

# Pull in external subroutines
require("subs/all.subroutines.pl");

# Initiate the process
&StartProcess; 

# Prepare the offset log
$offsetLog = "$logDir/offset/bulk-load-processed-to-es-offset-$args{partition}.log";
&d("Offset processing data will be saved to: $offsetLog\n");
if (-f "$offsetLog") {
  $lastOffset = read_file("$offsetLog");
}
if ($args{benchmark}) {
  $lastOffset = 0;
  &d("Benchmarking a full run from offset 0\n");
}


if ($lastOffset > 0) {
  &d("Resuming processing from offset $lastOffset\n");
} else {
  &d("No offset file found, starting from offset 0\n");
  $lastOffset = 0;
}
 
# Connect to Kafka 
my ( $connection, $consumer, $producer );
try {
  $connection = Kafka::Connection->new( host => 'localhost' );
  $consumer = Kafka::Consumer->new( Connection  => $connection );
} catch {
  my $error = $_;
  if ( blessed( $error ) && $error->isa( 'Kafka::Exception' ) ) {
      warn 'Error: (', $error->code, ') ',  $error->message, "\n";
      exit;
  } else {
      die $error;
  }
};

# Connect to ElasticSearch
&connectElastic;

# Prepare this to run forever
$keepRunning = 1;

# Benchmarking stats
$benchTotalItems = 0;
$bencht0 = [Time::HiRes::gettimeofday];

# BEGIN DAEMON LOOP
while($keepRunning) {

  # Start a timer
  my $tk0 = [Time::HiRes::gettimeofday];

  # Consume a chunk of messages
  my $messages = $consumer->fetch(
      $conf{kafkaTopicNameProcessed},
      $args{partition},     
      $lastOffset,
      24857600
  );
  
  my $processedCount = 0;
  my $totalItemCount = 0;
  my $totalKafkaProductionTime = 0;
  
  # Check to see if we got any messages
  if (@$messages < 1) {
    &d("! No additional messages consumed from partition $args{partition} offset $lastOffset, waiting 1s\n");
    sleep 1;
    next;
  }
  
  $interval = Time::HiRes::tv_interval ( $tk0, [Time::HiRes::gettimeofday]);
  &d("? Loaded incoming payload from Kafka from offset $lastOffset in $interval seconds\n");
  my $tk1 = [Time::HiRes::gettimeofday];
  
  foreach my $message ( @$messages ) {
    if ( $message->valid ) {
      $processedCount++;
      my $payload = $message->payload;
      my $itemJSON = JSON::XS->new->utf8->decode($payload);
      my $uuid = $itemJSON->{uuid};
      $itemBulk->index({ id => "$uuid", source => "$payload" });
    }
    $lastOffset = $message->next_offset;
  }
  &d("finishing bulk flush\n");
  $itemBulk->flush;
  open(my $OFFSETLOG, ">", $offsetLog) || die "FATAL: Unable to open $offsetLog - $!\n";
  print $OFFSETLOG $lastOffset;
  close($OFFSETLOG);

  $interval = Time::HiRes::tv_interval ( $tk1, [Time::HiRes::gettimeofday]);
  &d("e Bulk Loaded $processedCount items into ElasticSearch in ".sprintf("%.2f", $interval)."s (".sprintf("%.2f", $processedCount / $interval)." items/s)\n");

  $benchTotalItems += $processedCount;

}
# END DAEMON LOOP

sub connectElastic {

  # Nail up the Elastic Search connections
  our $e = Search::Elasticsearch->new(
    cxn_pool => 'Static',
    cxn => 'Hijk',
    nodes =>  [
      "$conf{esHost}:9200"
    ],
    # enable this for debug but BE CAREFUL it will create huge log files super fast
    # trace_to => ['File','/tmp/eslog.txt'],

    # Huge request timeout for bulk indexing
    request_timeout => 300
  );

  our $itemBulk = $e->bulk_helper(
    index => "$conf{esItemIndex}",
    max_count => '25000',
    max_time => '20',
    max_size => 0,
    type => "$conf{esItemType}",
  );
}
