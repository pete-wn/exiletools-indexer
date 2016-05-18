#!/usr/bin/perl


# This is intended to simply extract JSON data from a thread for analysis,
# such as when a Development Manifesto or Announcement thread contains new
# item JSON data

$|=1;

use LWP::UserAgent;
use Data::Dumper;
use HTML::Tree;
use JSON;
use JSON::XS;
use Encode;
use utf8::all;
use Parallel::ForkManager;
use Date::Parse;
use File::Path;
use Text::Unidecode;
require("subs/sub.formatJSON.pl");
require("subs/sub.itemBaseTypes.pl");

# Just null these out
sub sv {
}
sub d {
}

if ($ARGV[0] =~ /\d+/) {
  $threadid = $ARGV[0];
} else {
  die "ERROR: You must specify a threadid to scan.\n";
}

# Create a user agent
our $ua = LWP::UserAgent->new;
# Make sure it accepts gzip
our $can_accept = HTTP::Message::decodable;

my $targeturl = "http://www.pathofexile.com/forum/view-thread/$threadid";
my $response = $ua->get("$targeturl",'Accept-Encoding' => $can_accept);
my $content = $response->decoded_content;

# Extract the raw item JSON data from the javascript in the HTML
if ($content =~ /require\(\[\"PoE\/Item\/DeferredItemRenderer\"\], function\(R\) \{ \(new R\((.*?)\)\)\.run\(\)\; \}\)\;/) {
  $rawjson = $1;
} else {
  die "No JSON found in $threadid\n";
}


# Remove funky <<set formatting from raw json
$rawjson =~ s/\<\<set:(\S+?)\>\>//g;


# encode the JSON data into something perl can reference 
local $data = decode_json(encode("utf8", $rawjson));

# Break down the JSON into individual items
foreach my $itemx (@{$data}) {
  my $jsonx = JSON->new;
  undef %item;
  print "=============================================================\n";
  print "Item #".$itemx->[0]." RAW JSON:\n";
  print $jsonx->pretty->encode($itemx->[1])."\n";  
  print "** Modified ES JSON: ****************************************\n";
  my ($jsonout,$uuid,$itemStatus) = &formatJSON($itemx->[1]);
  print $jsonx->pretty->encode($jsonx->decode($jsonout))."\n";
}




