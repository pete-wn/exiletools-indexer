#!/usr/bin/perl

# NOTE: You must change this in the second line of the config also,
# because I'm lazy!
my $indexName = "dev-indexing-stats";

$config = '
{
    "aliases" : { },
    "settings" : {
      "index" : {
        "refresh_interval" : "10s",
        "number_of_shards" : "2",
        "number_of_replicas" : "1"
      }
    },
    "warmers" : { }
}
';

# Change dev-indexing-stats here as needed
$template = '
{
  "template" : "dev-indexing-stats*",
  "settings" : {
    "index" : {
      "refresh_interval" : "10s",
      "number_of_shards" : "2",
      "number_of_replicas" : "1"
    }
  },
  "mappings" : {
    "_default_" : {
      "_all" : {
        "enabled" : false
      },
      "dynamic_templates" : [ 
      {
        "do_not_analyze_string_fields" : {
          "match_mapping_type" : "string",
          "match" : "*",
          "mapping" : {
            "type" : "string",
            "index" : "not_analyzed"
          }
        }
      }
      ],
      "properties" : {
        "runTime" : {
          "type" : "date",
          "format" : "epoch_second"
        }
      }
    }
  }
}
';

print "Deleting $indexName Index:\n";
system("curl -XDELETE \'http://elasticsearch:9200/$indexName/?pretty\'");

print "Adding Template for $indexName Index:\n";
system("curl -XPUT \'http://elasticsearch:9200/_template/$indexName/?pretty\' -d \'$template\'");

print "Creating New $indexName Index:\n";
system("curl -XPUT \'http://elasticsearch:9200/$indexName/?pretty\' -d \'$config\'");
