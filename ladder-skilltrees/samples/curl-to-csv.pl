#!/usr/bin/perl

# This is just a simple perl script to request skilltree data and
# return the output as csv.
#
# It's very rudimentary and ineffecient as it's intended for one time
# use for generating some simple tables for blogs/etc.

use JSON::XS;

$league = $ARGV[0];
die "You must specify a league\n" unless ($ARGV[0]);
$aggField = $ARGV[1];
die "You must specify a field for aggregation!\n" unless ($ARGV[1]);

my $json = `curl -s -XGET 'http://elasticsearch:9200/skilltree/character/_search' -d '
{
  "query": {
    "bool": {
      "must": [
        { 
          "term": {
            "info.league": {
              "value": "$league"
            }
          }
        },
        {
          "term": {
            "info.runDate": {
              "value": "20160216"
            }
          }
        },
        {
          "term": {
            "info.private": {
              "value": false
            }
          }
        }
      ]
    }
  },
  "aggs": {
    "agg": {
      "terms": {
        "field": "$aggField",
        "size": 500
      }
    }
  }, 
  size:0
}
'`;

my $data = decode_json($json);

my $hits = $data->{hits}->{total};
$rank = 0;

#print "$hits Total Hits\n\n";
#print "League,Rank,Key,Count\n";

foreach $bucket (@{$data->{aggregations}->{agg}->{buckets}}) {
  $rank++;
  print "\"$league\",\"$rank\",\"$bucket->{key}\",\"$bucket->{doc_count}\"\n";
}
