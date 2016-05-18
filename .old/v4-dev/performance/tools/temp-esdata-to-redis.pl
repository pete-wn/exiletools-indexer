#!/usr/bin/perl

$|=1;
use JSON;
use JSON::XS;
use Encode;
use utf8::all;
use Search::Elasticsearch;
use Text::Unidecode;
use Data::Dumper;
use Redis;

# Load in external subroutines
require("subs/all.subroutines.pl");
require("subs/sub.formatJSON.pl");

&StartProcess;

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

$redis = Redis->new;

# ElasticSearch information to bring back
# shop.stash.stashID
# shop.verified
# uuid
# shop.note
# shop.stash.stashName
# shop.modified
# shop.updated
# shop.added

my $scroll = $e->scroll_helper(
  index       => 'poe',
  type => 'item',
  search_type => 'scan',
  size        => 10000,
  body => {
    "_source" => [ "shop.stash.stashID", "shop.stash.stashName", "shop.verified", "shop.note", "shop.modified", "shop.update", "shop.added", "uuid" ],
  }
);

$count = 0;
while (my $doc = $scroll->next) {
  $count++;
  my $jsonout = JSON::XS->new->utf8->encode($doc->{"_source"});
  my $uuid = $doc->{"_source"}->{uuid};
  print localtime()." [$count] Adding $uuid to Redis\n" if ($count % 1000 == 0);
  $redis->set("$uuid" => "$jsonout");
}
