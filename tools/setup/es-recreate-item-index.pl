#!/usr/bin/perl

# NOTE: You must change this in the second line of the config also,
# because I'm lazy!
my $indexName = "poedev";

$config = '
{
    "aliases" : { },
    "settings" : {
      "index" : {
        "refresh_interval" : "3s",
        "number_of_shards" : "3",
        "number_of_replicas" : "1",
        "requests.cache.enable" : true
      }
    },
    "warmers" : { }
}
';

# Change poedev here as needed
$template = '
{
  "template" : "poedev*",
  "settings" : {
    "index" : {
      "refresh_interval" : "3s",
      "number_of_shards" : "3",
      "number_of_replicas" : "1",
      "requests.cache.enable" : true
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
          "max_gram" : "12",
          "token_chars": [ "letter", "digit", "whitespace", "punctuation", "symbol" ]
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
      }, {
        "all_numbers_as_long_for_decimals" : {
          "mapping" : {
            "type" : "double"
          },
          "match_mapping_type" : "long"
        }
      }
      ],
      "properties" : {
        "properties" : {
          "properties" : {
            "Quality" : {
              "type" : "double"
            },
            "Weapon" : {
              "properties" : {
                "Attacks per Second" : {
                  "type" : "double"
                },
                "Critical Strike Chance" : {
                  "type" : "double"
                }
              }
            }  
          }
        },
        "shop" : {
          "properties" : {
            "added" : {
              "type" : "date",
              "format" : "strict_date_optional_time||epoch_millis"
            },
            "modified" : {
              "type" : "date",
              "format" : "strict_date_optional_time||epoch_millis"
            },
            "updated" : {
              "type" : "date",
              "format" : "strict_date_optional_time||epoch_millis"
            },
            "amount" : {
              "type" : "double"
            },
            "stash" : {
              "properties" : {
                "xLocation" : {
                  "type" : "double"
                },
                "yLocation" : {
                  "type" : "double"
                }
              }
            }
          }
        },
        "info" : {
          "properties" : {
            "tokenized" : {
              "properties" : {
                "fullName" : {
                  "type" : "string",
                  "index" : "analyzed",
                  "analyzer" : "edge_ngram"
                },
                "descrText" : {
                  "type" : "string",
                  "index" : "analyzed",
                  "analyzer" : "edge_ngram"
                },
                "DivinationReward" : {
                  "type" : "string",
                  "index" : "analyzed",
                  "analyzer" : "edge_ngram"
                },
                "flavourText" : {
                  "type" : "string",
                  "index" : "analyzed",
                  "analyzer" : "edge_ngram"
                }
              }
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
