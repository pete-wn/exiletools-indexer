#!/usr/bin/perl

$|=1;
use JSON;
use JSON::XS;
use Encode;
use utf8::all;
use Search::Elasticsearch;
use Text::Unidecode;

# Load in external subroutines
require("subs/all.subroutines.pl");
require("subs/sub.formatJSON.pl");

&StartProcess;

# Nail up the Elastic Search connections
local $e = Search::Elasticsearch->new(
  cxn_pool => 'Sniff',
  cxn => 'Hijk',
  nodes =>  [
#    "$conf{esHost}:9200"
# override test host
    "master.pwx:9200"
  ],
  # enable this for debug but BE CAREFUL it will create huge log files super fast
#   trace_to => ['File','/tmp/eslog.txt'],

  # Huge request timeout for bulk indexing
  request_timeout => 300
); 

# itemType -> baseItemType
my $searchES = $e->search(
#  index => "$conf{esItemIndex}",
# override test index
  index => "poe",
  type => "$conf{esItemType}",
  body => {
    aggs => {
      data => {
        terms => {
          field => "attributes.baseItemType",
          size => 500
        },
        aggs => {
          subData => {
            terms => {
              field => "attributes.itemType",
              size => 500
            }
          }
        }
      }
    },
    size => 2000
  }
);

my %h;

foreach $base (@{$searchES->{aggregations}->{data}->{buckets}}) {
  print "analyzing $base->{key}\n";
  foreach $itemType (@{$base->{subData}->{buckets}}) {
    print "  processing $itemType->{key}\n";
    $h{"$itemType->{key}"} = "$base->{key}";
  }
}

my $jsonout = JSON::XS->new->utf8->pretty->encode(\%h);
print $jsonout."\n";
