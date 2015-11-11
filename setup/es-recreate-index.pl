#!/usr/bin/perl

# NOTE: You must change this in the second line of the config also,
# because I'm lazy!
my $indexName = "poedev";

$config = '
{
  "poedev" : {
    "aliases" : { },
    "mappings" : {
      "_default_" : {
        "_all" : {
          "enabled" : true
        },
        "dynamic_templates" : [ {
          "string_fields" : {
            "mapping" : {
              "index" : "not_analyzed",
              "omit_norms" : true,
              "type" : "string"
            },
            "match" : "*",
            "match_mapping_type" : "string"
          }
        }, {
          "number_as_double" : {
            "mapping" : {
              "type" : "double"
            },
            "match" : "*",
            "match_mapping_type" : "long"
          }
        } ]
      },
      "item" : {
        "_all" : {
          "enabled" : true
        },
        "dynamic_templates" : [ {
          "string_fields" : {
            "mapping" : {
              "index" : "not_analyzed",
              "omit_norms" : true,
              "type" : "string"
            },
            "match" : "*",
            "match_mapping_type" : "string"
          }
        }, {
          "number_as_double" : {
            "mapping" : {
              "type" : "double"
            },
            "match" : "*",
            "match_mapping_type" : "long"
          }
        } ],
        "properties" : {
          "info" : {
            "properties" : {
              "descrText" : {
                "type" : "string"
              },
              "flavourText" : {
                "type" : "string"
              },
              "fullNameTokenized" : {
                "type" : "string"
              }
            }
          },
          "shop" : {
            "properties" : {
              "added" : {
                "type" : "date",
                "format" : "strict_date_optional_time||epoch_millis"
              },
              "lastUpdateDB" : {
                "type" : "date",
                "format" : "yyyy-MM-dd HH:mm:ss"
              },
              "modified" : {
                "type" : "date",
                "format" : "strict_date_optional_time||epoch_millis"
              },
              "updated" : {
                "type" : "date",
                "format" : "strict_date_optional_time||epoch_millis"
              }
            }
          }
        }
      }
    },
    "settings" : {
      "index" : {
        "creation_date" : "1447276364474",
        "refresh_interval" : "60s",
        "number_of_shards" : "5",
        "number_of_replicas" : "1",
        "uuid" : "WyjvreIeSP2B7982jWZzAQ",
        "version" : {
          "created" : "2000099"
        }
      }
    },
    "warmers" : { }
  }
}
';

print "Deleting $indexName Index:\n";
system("curl -XDELETE \'http://elasticsearch:9200/$indexName/?pretty\'");

print "Creating New $indexName Index:\n";
system("curl -XPUT \'http://elasticsearch:9200/$indexName/?pretty\' -d \'$config\'");

