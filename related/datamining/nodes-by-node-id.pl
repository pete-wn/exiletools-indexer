#!/usr/bin/perl

use JSON::XS;

my $json = `curl -s -XGET 'http://api.exiletools.com/skilltrees/_search' -d '
{
  "query": {
    "bool": {
      "must": [
        { 
          "term": {
            "info.league": {
              "value": "Perandus"
            }
          }
        },
        {
          "term": {
            "info.runDate": {
              "value": "20160318"
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
    "skillNodes": {
      "nested": {
        "path": "skillNodes"
      },
      "aggs": {
        "nodename": {
          "terms": {
            "field": "skillNodes.node",
            "size": 100000
          }
        }
      }
    }
  }, 
  size:0
}'`;
my $data = decode_json($json);


$total = $data->{aggregations}->{skillNodes}->{doc_count};
$rank = 0;
foreach $bucket (@{$data->{aggregations}->{skillNodes}->{nodename}->{buckets}}) {
  $rank++;
  print "$rank,$bucket->{key},$bucket->{doc_count},".sprintf("%.02f", ($bucket->{doc_count} / $total * 100))."%\n";
}

