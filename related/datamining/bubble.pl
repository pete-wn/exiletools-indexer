#!/usr/bin/perl

# This script will fetch the ladder for a league then each of the skilltrees for
# each character on this league. 
#
# See https://github.com/trackpete/exiletools-indexer/issues/90 for development
# status.

$|=1;

use LWP::UserAgent;
use JSON;
use JSON::XS;

# The official pathofexile.com URL for getting character skilltree data
$skilltreeURL = 'https://www.pathofexile.com/character-window/get-passive-skills?reqData=0';

# Create the global nodeHash 
our %nodeHash;

# Create the %nodeHash lookup table for node information
&createNodeHash;


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
        "noteable": {
          "filter": {
            "term": {
              "skillNodes.isNoteable": true
            }
          },
          "aggs": {
            "nodename": {
              "terms": {
                "field": "skillNodes.node",
                "size": 5000
              }
            }
          }
        }
      }
    }
  }, 
  size:0
}'`;
my $data = decode_json($json);


$total = $data->{aggregations}->{skillNodes}->{noteable}->{doc_count};
$rank = 0;
foreach $bucket (@{$data->{aggregations}->{skillNodes}->{noteable}->{nodename}->{buckets}}) {
  $rank++;
#  print "$rank,$bucket->{key},$bucket->{doc_count},".sprintf("%.02f", ($bucket->{doc_count} / $total * 100))."%\n";
  my $id = $bucket->{key};
  print "{ x: ".$nodeHash{$id}{x}.", y: ".$nodeHash{$id}{y}.", z: ".$bucket->{doc_count}.", name: \'".$nodeHash{$id}{name}." (Rank $rank)\' },\n";
}




sub createNodeHash {
  # This URL should point to the official pathofexile.com skilltree
  my $fullSkilltreeURL = 'https://www.pathofexile.com/passive-skill-tree';

  # Fetch skilltree from pathofexile.com
  my $ua = LWP::UserAgent->new;
  my $response = $ua->get("$fullSkilltreeURL",'Accept-Encoding' => $can_accept);

  # Decode response
  my $content = join("", split(/\n/, $response->decoded_content));

  # Clean out everything before the skill tree data
  $content =~ s/^.*var passiveSkillTreeData = //o;
  # Clean out everything after the skill tree data
  $content =~ s/,\"imageZoomLevels.*$/\}/o;



  # encode the JSON data into something perl can reference 
  my $data = decode_json($content);


  foreach $node (@{$data->{nodes}}) {
    my $id = $node->{id};
    $nodeHash{$id}{name} = $node->{dn};
    $nodeHash{$id}{icon} = "https://p7p4m6s5.ssl.hwcdn.net/image".$node->{icon};
    $nodeHash{$id}{icon} =~ s/\\//g;
    $nodeHash{$id}{isNoteable} = $node->{not};
    $nodeHash{$id}{isKeystone} = $node->{ks};
    $nodeHash{$id}{bonuses} = $node->{sd};
  }

  foreach $node (keys %{$data->{groups}}) {
    foreach $id (@{$data->{groups}->{$node}->{n}}) {
      $nodeHash{$id}{x} = $data->{groups}->{$node}->{x};
      if ($data->{groups}->{$node}->{y} =~ /^-/) {
        $data->{groups}->{$node}->{y} =~ s/^-//o;
      } else {
        $data->{groups}->{$node}->{y} =~ s/^/-/o;
      }

      $nodeHash{$id}{y} = $data->{groups}->{$node}->{y};
    }
  }


#  foreach $node (keys(%nodeHash)) {
#    print "$node | $nodeHash{$node}{name} | $nodeHash{$node}{x} | $nodeHash{$node}{y}\n";
#  }
}
