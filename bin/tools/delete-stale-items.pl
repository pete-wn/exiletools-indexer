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
    "$conf{esHost}:9200",
  ],
  # enable this for debug but BE CAREFUL it will create huge log files super fast
#   trace_to => ['File','/tmp/eslog.txt'],

  # Huge request timeout for bulk indexing
  request_timeout => 1200
); 

$keepRunning = 1;

while($keepRunning) {
  my $searchES = $e->search(
#    index => "$conf{esItemIndex}",
    index => "poe",
    type => "$conf{esItemType}",
    body => {
      query => {
        bool => {
          must => [
            { 
              range => {
                "shop.updated" => { lte => "now-30d/d" }
              }
            }
#            },
#            {
#              term => { "shop.verified" => { value => "YES" } }
#            }
          ]
        }
      }
    }
  );
  print "Found ".$searchES->{hits}->{total}." verified items not updated in 14 days, deleting them...\n";

  # This has to be done in curl, there's no Perl API for this plugin
  $deleteQuery = '{
"query": {
  "bool": {
    "must": [
      {
        "range": {
          "shop.updated": {
            "lte": "now-30d/d"
          }
        }
      }
    ]
  },
  size:1000,
  timeout:300
}
}';

  my $deleteCommand = "curl -XDELETE \'http://$conf{esHost}:9200/poe/item/_query\' -d \'$deleteQuery\'";
  print "$deleteCommand\n";


exit;
}

