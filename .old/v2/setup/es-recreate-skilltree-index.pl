#!/usr/bin/perl

# NOTE: You must change this in the second line of the config also,
# because I'm lazy!
my $indexName = "skilltree";

$config = '
{
    "aliases" : { },
    "settings" : {
      "index" : {
        "refresh_interval" : "60s",
        "number_of_shards" : "3",
        "number_of_replicas" : "1"
      }
    },

    "warmers" : { }
}
';

# Change skilltree here as needed
$template = '
{
  "template" : "skilltree*",
  "settings" : {
    "index" : {
      "refresh_interval" : "60s",
      "number_of_shards" : "3",
      "number_of_replicas" : "1"
    },
    "analysis" : {
      "analyzer" : {
        "edge_ngram" : {
          "tokenizer" : "edge_ngram"
        },
        "analyzer_keyword": {
          "tokenizer" : "keyword",
          "filter" : "lowercase"
        }
      },
      "tokenizer" : {
        "edge_ngram" : {
          "type" : "edgeNGram",
          "min_gram" : "3",
          "max_gram" : "6",
          "token_chars": [ "letter", "digit" ]
        }
      }
    }
  },
  "mappings" : {
    "_default_" : {
      "_all" : {
        "enabled" : true
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
        "info" : {
          "properties" : {
            "runDate" : {
              "type" : "date",
              "format" : "yyyyMMdd"
            },
            "characterTokenized" : {
              "type" : "string",
              "index" : "analyzed",
              "analyzer" : "edge_ngram"
            },
            "accountNameTokenized" : {
              "type" : "string",
              "index" : "analyzed",
              "analyzer" : "edge_ngram"
            }
          }
        },
        "skillNodes" : {
          "type" : "nested",
          "properties" : {
            "node" : {
              "type" : "integer"
            },
            "chosen" : {
              "type" : "boolean"
            },
            "nodename" : {
              "type" : "string",
              "index" : "not_analyzed"
            },
            "icon" : {
              "type" : "string",
              "index" : "not_analyzed"
            },
            "isKeystone" : {
              "type" : "boolean"
            },
            "isNoteable" : {
              "type" : "boolean"
            }
          }
        },
        "jewels" : {
          "type" : "nested",
          "properties" : {
            "explicitMods" : {
              "type" : "nested"
            },
            "implicitMods" : {
              "type" : "nested"
            }
          }
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
