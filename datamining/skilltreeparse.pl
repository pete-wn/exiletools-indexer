#!/usr/bin/perl

$league = "Perandus";
$run = "20160318";
$outdir = "csv";

use JSON::XS;

my $json = `curl -s -XGET 'http://api.exiletools.com/skilltrees/_search' -d '
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
              "value": "$run"
            }
          }
        }
      ]
    }
  },
  "aggs": {
    "jewelSlots" : {
      "terms": {
        "field": "info.jewelSlots",
        "size": 100
      }
    },
    "skillPoints" : {
      "terms": {
        "field": "info.skillPointsUsed",
        "size": 150
      }
    },
    "ascskillPoints" : {
      "terms": {
        "field": "info.ascendancySkillPointsUsed",
        "size": 150
      }
    },
    "classID" : {
      "terms": {
        "field": "info.classID",
        "size": 150
      }
    },
    "level" : {
      "terms": {
        "field": "info.level",
        "size": 150
      }
    },
    "ascendancyClasses" : {
      "terms": {
        "field": "info.ascendancyName",
        "size": 150
      }
    }
  },
  size:0
}
'`;

my $data = decode_json($json);

my $total = $data->{hits}->{total};


print " Skill tree counts\n";
open(OUT, ">$outdir/number-of-skill-points.csv");
print OUT "skillpoints,count,percentage\n";
foreach $bucket(@{$data->{aggregations}->{skillPoints}->{buckets}}) {
  print OUT "$bucket->{key},$bucket->{doc_count},".sprintf("%.02f", ($bucket->{doc_count} / $total * 100))."%\n";
}
close(OUT);

print " jewel counts\n";
open(OUT, ">$outdir/number-of-jewel-points.csv");
print OUT "jewelpoints,count,percentage\n";
foreach $bucket(@{$data->{aggregations}->{jewelSlots}->{buckets}}) {
  print OUT "$bucket->{key},$bucket->{doc_count},".sprintf("%.02f", ($bucket->{doc_count} / $total * 100))."%\n";
}
close(OUT);

print " ascendancy skill point counts\n";
open(OUT, ">$outdir/number-of-ascendancy-points.csv");
print OUT "ascendancypoints,count,percentage\n";
foreach $bucket(@{$data->{aggregations}->{ascskillPoints}->{buckets}}) {
  print OUT "$bucket->{key},$bucket->{doc_count},".sprintf("%.02f", ($bucket->{doc_count} / $total * 100))."%\n";
}
close(OUT);

print " ascendancy classes counts\n";
open(OUT, ">$outdir/ascendancy-classes.csv");
print OUT "ascendancyclass,count,percentage\n";
foreach $bucket(@{$data->{aggregations}->{ascendancyClasses}->{buckets}}) {
  print OUT "$bucket->{key},$bucket->{doc_count},".sprintf("%.02f", ($bucket->{doc_count} / $total * 100))."%\n";
}
close(OUT);

$id{0} = "Scion";
$id{1} = "Marauder";
$id{2} = "Ranger";
$id{3} = "Witch";
$id{4} = "Duelist";
$id{5} = "Templar";
$id{6} = "Shadow";


print " base classes by id counts\n";
open(OUT, ">$outdir/base-classes.csv");
print OUT "classid,class,count,percentage\n";
foreach $bucket(@{$data->{aggregations}->{classID}->{buckets}}) {
  print OUT "$bucket->{key},$id{$bucket->{key}},$bucket->{doc_count},".sprintf("%.02f", ($bucket->{doc_count} / $total * 100))."%\n";
}
close(OUT);

print " level counts\n";
open(OUT, ">$outdir/levels.csv");
print OUT "level,count,percentage\n";
foreach $bucket(@{$data->{aggregations}->{level}->{buckets}}) {
  print OUT "$bucket->{key},$bucket->{doc_count},".sprintf("%.02f", ($bucket->{doc_count} / $total * 100))."%\n";
}
close(OUT);



print " Get node data\n";

my $json = `curl -s -XGET 'http://api.exiletools.com/skilltrees/_search' -d '
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
              "value": "$run"
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
            "field": "skillNodes.nodename",
            "size": 5000
          }
        }
      }
    }
  }, 
  size:0
}
'`;

my $data = decode_json($json);

$totalNodes = $data->{aggregations}->{skillNodes}->{doc_count};
print "$totalNodes total nodes found.\n";
my $rank=0;
open(OUT, ">$outdir/all-nodes.csv");
print OUT "rank,nodename,count,percentage\n";
foreach $bucket (@{$data->{aggregations}->{skillNodes}->{nodename}->{buckets}}) {
  $rank++;
  print OUT "$rank,$bucket->{key},$bucket->{doc_count},".sprintf("%.02f", ($bucket->{doc_count} / $totalNodes * 100))."%\n"; 

}
close(OUT);

print " Get Noteable data\n";
my $json = `curl -s -XGET 'http://api.exiletools.com/skilltrees/_search' -d '
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
              "value": "$run"
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
        "notable": {
          "filter": {
            "term": {
              "skillNodes.isNoteable": true
            }
          },
          "aggs": {
            "nodename": {
              "terms": {
                "field": "skillNodes.nodename",
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

$totalNodes = $data->{aggregations}->{skillNodes}->{notable}->{doc_count};
print "$totalNodes total nodes found.\n";
my $rank=0;
open(OUT, ">$outdir/noteable-nodes.csv");
print OUT "rank,nodename,count,percentage\n";
foreach $bucket (@{$data->{aggregations}->{skillNodes}->{notable}->{nodename}->{buckets}}) {
  $rank++;
  print OUT "$rank,$bucket->{key},$bucket->{doc_count},".sprintf("%.02f", ($bucket->{doc_count} / $totalNodes * 100))."%\n";
}
close(OUT);

print " Keystone data\n";
my $json = `curl -s -XGET 'http://api.exiletools.com/skilltrees/_search' -d '
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
              "value": "$run"
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
        "notable": {
          "filter": {
            "term": {
              "skillNodes.isKeystone": true
            }
          },
          "aggs": {
            "nodename": {
              "terms": {
                "field": "skillNodes.nodename",
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

$totalNodes = $data->{aggregations}->{skillNodes}->{notable}->{doc_count};
print "$totalNodes total nodes found.\n";
my $rank = 0;
open(OUT, ">$outdir/keystone-nodes.csv");
print OUT "rank,nodename,count,percentage\n";
foreach $bucket (@{$data->{aggregations}->{skillNodes}->{notable}->{nodename}->{buckets}}) {
  $rank++;
  print OUT "$rank,$bucket->{key},$bucket->{doc_count},".sprintf("%.02f", ($bucket->{doc_count} / $totalNodes * 100))."%\n";
}
close(OUT);

print " Jewel frametype\n";
my $json = `curl -s -XGET 'http://api.exiletools.com/skilltrees/_search' -d '
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
              "value": "$run"
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
    "jewels": {
      "nested": {
        "path": "jewels"
      },
      "aggs": {
        "frameType": {
          "terms": {
            "field": "jewels.frameType",
            "size": 10
          }
        }
      }
    }
  }, 
  size:0
}'`;
my $data = decode_json($json);

$totalJewels = $data->{aggregations}->{jewels}->{doc_count};
print "$totalJewels jewels found.\n";
my $rank = 0;
open(OUT, ">$outdir/jewel-rarity.csv");
print OUT "rank,rarity,count,percentage\n";
foreach $bucket (@{$data->{aggregations}->{jewels}->{frameType}->{buckets}}) {
  $rank++;
  print OUT "$rank,$bucket->{key},$bucket->{doc_count},".sprintf("%.02f", ($bucket->{doc_count} / $totalJewels * 100))."%\n";
}
close(OUT);

print "popular unique jewels\n";
my $json = `curl -s -XGET 'http://api.exiletools.com/skilltrees/_search' -d '
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
              "value": "$run"
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
    "jewels": {
      "nested": {
        "path": "jewels"
      },
      "aggs": {
        "filter": {
          "filter": {
            "term": {
              "jewels.frameType": 3
            }
          },
          "aggs": {
            "nodename": {
              "terms": {
                "field": "jewels.name",
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

$total = $data->{aggregations}->{jewels}->{filter}->{doc_count};
print "$total found.\n";
$rank = 0;
open(OUT, ">$outdir/unique-jewels.csv");
print OUT "rank,jewelname,count,percentage\n";
foreach $bucket (@{$data->{aggregations}->{jewels}->{filter}->{nodename}->{buckets}}) {
  $rank++;
  print OUT "$rank,$bucket->{key},$bucket->{doc_count},".sprintf("%.02f", ($bucket->{doc_count} / $total * 100))."%,".sprintf("%.02f", ($bucket->{doc_count} / $totalJewels * 100))."%\n";
}
close(OUT);

print " Get Ascendancy Node data\n";
my $json = `curl -s -XGET 'http://api.exiletools.com/skilltrees/_search' -d '
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
              "value": "$run"
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
        "aggfilter": {
          "filter": {
            "term": {
              "skillNodes.isAscendancyNode": true
            }
          },
          "aggs": {
            "nodename": {
              "terms": {
                "field": "skillNodes.nodename",
                "size": 5000
              },
              "aggs": {
                "class": {
                  "terms": {
                    "field": "skillNodes.ascendancyName",
                    "size": 10
                  }
                }
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

$totalNodes = $data->{aggregations}->{skillNodes}->{aggfilter}->{doc_count};
print "$totalNodes total nodes found.\n";
my $rank=0;
open(OUT, ">$outdir/ascendancy-nodes.csv");
print OUT "rank,ascendancy,nodename,count,percentage\n";
foreach $bucket (@{$data->{aggregations}->{skillNodes}->{aggfilter}->{nodename}->{buckets}}) {
  $rank++;
  foreach $subbucket (@{$bucket->{class}->{buckets}}) {
    print OUT "$rank,\"$subbucket->{key}\",\"$bucket->{key}\",$subbucket->{doc_count},".sprintf("%.02f", ($subbucket->{doc_count} / $totalNodes * 100))."%\n";
  }
}
close(OUT);




print " Get Ascendancy Noteable Node data\n";
my $json = `curl -s -XGET 'http://api.exiletools.com/skilltrees/_search' -d '
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
              "value": "$run"
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
        "aggfilter": {
          "filter": {
            "bool": {
              "must": [
                { 
                  "term": {
                    "skillNodes.isNoteable": {
                      "value": "true"
                    }
                  }
                },
                {
                  "term": {
                    "skillNodes.isAscendancyNode": {
                      "value": "true"
                    }
                  }
                }        
              ]
            }            
          },
          "aggs": {
            "nodename": {
              "terms": {
                "field": "skillNodes.nodename",
                "size": 5000
              },
              "aggs": {
                "class": {
                  "terms": {
                    "field": "skillNodes.ascendancyName",
                    "size": 10
                  }
                }
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

$totalNodes = $data->{aggregations}->{skillNodes}->{aggfilter}->{doc_count};
print "$totalNodes total nodes found.\n";
my $rank=0;
open(OUT, ">$outdir/ascendancy-noteable-nodes.csv");
print OUT "rank,ascendancy,nodename,count,percentage\n";
foreach $bucket (@{$data->{aggregations}->{skillNodes}->{aggfilter}->{nodename}->{buckets}}) {
  $rank++;
  foreach $subbucket (@{$bucket->{class}->{buckets}}) {
    print OUT "$rank,\"$subbucket->{key}\",\"$bucket->{key}\",$subbucket->{doc_count},".sprintf("%.02f", ($subbucket->{doc_count} / $totalNodes * 100))."%\n";
  }
}
close(OUT);



print " Get Ascendancy NON Noteable Node data\n";
my $json = `curl -s -XGET 'http://api.exiletools.com/skilltrees/_search' -d '
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
              "value": "$run"
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
        "aggfilter": {
          "filter": {
            "bool": {
              "must": [
                {
                  "term": {
                    "skillNodes.isAscendancyNode": {
                      "value": "true"
                    }
                  }
                }        
              ],
              "must_not" : [
                {
                  "term": {
                    "skillNodes.isNoteable": {
                      "value": "true"
                    }
                  }
                }
              ]
            }            
          },
          "aggs": {
            "nodename": {
              "terms": {
                "field": "skillNodes.nodename",
                "size": 5000
              },
              "aggs": {
                "class": {
                  "terms": {
                    "field": "skillNodes.ascendancyName",
                    "size": 10
                  }
                }
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

$totalNodes = $data->{aggregations}->{skillNodes}->{aggfilter}->{doc_count};
print "$totalNodes total nodes found.\n";
my $rank=0;
open(OUT, ">$outdir/ascendancy-normal-nodes.csv");
print OUT "rank,ascendancy,nodename,count,percentage\n";
foreach $bucket (@{$data->{aggregations}->{skillNodes}->{aggfilter}->{nodename}->{buckets}}) {
  $rank++;
  foreach $subbucket (@{$bucket->{class}->{buckets}}) {
    print OUT "$rank,\"$subbucket->{key}\",\"$bucket->{key}\",$subbucket->{doc_count},".sprintf("%.02f", ($subbucket->{doc_count} / $totalNodes * 100))."%\n";
  }
}
close(OUT);
