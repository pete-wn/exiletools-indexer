#!/usr/bin/perl

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

our $totalProcessingTime;
our $totalUpdates;

$SIG{INT} = \&catch_int;
sub catch_int {
  &d("!!! [$$] Caught SIGINT, exiting...\n");
  &d("Performance: $totalUpdates processed in $totalProcessingTime seconds (".($totalProcessingTime / $totalUpdates)." sec / update)\n");
  &ExitProcess;
  exit 3;
}

# Load in external subroutines
require("subs/all.subroutines.pl");
&StartProcess;

# ========= KAFKA TESTING =====================================================
use Scalar::Util qw(
    blessed
);
use Try::Tiny;
 
use Kafka qw(
    $BITS64
);
use Kafka::Connection;
use Kafka::Producer;
use Kafka::Consumer;
my ( $connection, $producer );
try {
    #-- Connect to local cluster
    $connection = Kafka::Connection->new( host => 'localhost' );
    #-- Producer
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
 
# END KAFKA TESTING ============================================================











# The official Public Stash Tab API URL
our $apiURL = "http://www.pathofexile.com/api/public-stash-tabs";

# This adds support to serialize data from a file source instead of the web API for
# more efficient benchmarking using repeatable data
if ($args{usefiles}) {
  $srcFileDir = "/pwxdata/poe/stashtabs/riverData/20160321";
  $next_change_id = "2198709-2322115-2167158-2546114-2419716";
}

# Create a user agent
our $ua = LWP::UserAgent->new;
# Make sure it accepts gzip
our $can_accept = HTTP::Message::decodable;

my $keepRunning = 1;

while($keepRunning) {
  $kr0 = [Time::HiRes::gettimeofday];
  my $status = &RunRiver("$next_change_id");
  if ($status eq "Maintenance") {
    &d("Maintenance message received on pathofexile.com, sleeping for 2 minutes!\n");
    sleep 120;
  } elsif ($status =~ /^Failed/) {
    &d("Web Server Error: $status | Sleeping for 2 minutes!\n");
    sleep 120;
  } elsif ($status =~ /next_change_id:(.*?)$/) {
    $next_change_id = $1;
#    sleep 1;
  } else {
    &d("FATAL ERROR: RunRiver did not return a valid status! \"$status\" Aborting!\n");
    die;
  }
  $interval = Time::HiRes::tv_interval ( $kr0, [Time::HiRes::gettimeofday]);
  &d("One full update in $interval seconds\n");
  if ($totalUpdates == 500) {
    &d("Performance: $totalUpdates processed in $totalProcessingTime seconds (".($totalProcessingTime / $totalUpdates)." sec / update)\n");
    &ExitProcess;
  }
}

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

  # Remove funky <<set formatting
  $content =~ s/\<\<set:(\S+?)\>\>//g;

  # encode the JSON riverData into something perl can reference 
  my %riverData = %{JSON::XS->new->utf8->allow_nonref->decode($content)};

  # All done and loaded into a perl hash for processing. Booya.
  $interval = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
  &d("! Downloaded and pre-processed as JSON in $interval seconds\n");

  $t0 = [Time::HiRes::gettimeofday];

  foreach $stash (@{$riverData{stashes}}) {
    $changeStats{Stashes}++;

    # winner for now
    my $jsonout = JSON::XS->new->utf8->encode($stash);

    my $partition;
    if ($conf{kafkaTopicPartitionsIncoming} > 1) {
      $partition = int(rand($conf{kafkatopicPartitionsIncoming}));
    } else {
      $partition = 0;
    }
    # lazily doing partitions with fixed stuff for now during testing
    $producer->send(
        $conf{kafkaTopicNameIncoming},
        $partition,
        $jsonout
    );
 

    # Slower / less cool / not using
    # my $jsonout = encode_json $stash;
    # my $hashout = Dumper \$stash;
    # my $binout = &Storable::nfreeze($stash);

    
  }

  if ($changeStats{Stashes} > 0) {
    $interval = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
    &d("This stash tab api update processed in $interval seconds\n");
    &d("$change_id $changeStats{Stashes} stashes in this id\n");
    $totalProcessingTime += $interval;
    $totalUpdates++;
  } else {
    &d("! No changes found this id! Will retry.\n");
  }

  if ($riverData{next_change_id}) {
    return("next_change_id:$riverData{next_change_id}");
  } else {
    return("ERROR no next_change_id found!");
  }

}
