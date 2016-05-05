#!/usr/bin/perl

$|=1;
use JSON;
use JSON::XS;
use Encode;
use utf8::all;
use Search::Elasticsearch;
use Text::Unidecode;
use Data::Dumper;

# Load in external subroutines
require("subs/all.subroutines.pl");
require("subs/sub.formatJSON.pl");

&StartProcess;

# Nail up the Elastic Search connections
local $e = Search::Elasticsearch->new(
  cxn_pool => 'Sniff',
  cxn => 'Hijk',
  nodes =>  [
    "elasticsearch:9200",
    "elasticsearch2:9200",
    "elasticsearch3:9200"
  ],
  # enable this for debug but BE CAREFUL it will create huge log files super fast
#   trace_to => ['File','/tmp/eslog.txt'],

  # Huge request timeout for bulk indexing
  request_timeout => 600
); 

local $edst = Search::Elasticsearch->new(
  cxn_pool => 'Static',
  cxn => 'Hijk',
  nodes =>  [
    "master.pwx:9200",
  ],
  # enable this for debug but BE CAREFUL it will create huge log files super fast
#   trace_to => ['File','/tmp/eslog.txt'],

  # Huge request timeout for bulk indexing
  request_timeout => 60
);

local $bulkdst = $edst->bulk_helper(
  index => 'poe20160505',
  type => 'item',
  max_count => '20000',
  max_time => '30'
)
-> reindex(
    source => {
      es => $e,
      index => 'poe'
    }
  );



#my $scroll = $e->scroll_helper(
#  index       => 'poe',
#  type => 'item',
#  search_type => 'scan',
#  size        => 1000,
#);
#
#$count = 0;
#while (my $doc = $scroll->next) {
#  $count++;
#  print localtime()." [$count] reindex in progress\n" if ($count % 1000 == 0);
#
#  $bulkdst->reindex(
#    source => $doc
#  ); 
#}
#$bulkdst->flush;
