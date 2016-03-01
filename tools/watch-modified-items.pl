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
    "$conf{esHost2}:9200",
    "$conf{esHost3}:9200"
  ],
  # enable this for debug but BE CAREFUL it will create huge log files super fast
#   trace_to => ['File','/tmp/eslog.txt'],

  # Huge request timeout for bulk indexing
  request_timeout => 300
); 

$keepRunning = 1;

while($keepRunning) {
  $timestamp = time() * 1000;

  # Only bother if we've run once
  if ($timestamp && $lasttime) {
    my $searchES = $e->search(
      index => "$conf{esItemIndex}",
      type => "$conf{esItemType}",
      body => {
        query => {
          bool => {
            must => [
              { 
                range => {
                  "shop.modified" => { gte => $lasttime, lte => $timestamp }
                }
              }
            ]
          }
        },
        size => 2000
      }
    );
    if ($searchES->{hits}->{total} > 0) {
      &d($searchES->{hits}->{total}." items modified since ".localtime($lasttime)."\n");
      foreach $item (@{$searchES->{hits}->{hits}}) {
        print "$item->{_source}->{shop}->{sellerAccount} | $item->{_source}->{info}->{fullName} | $item->{_source}->{shop}->{verified} | $item->{_source}->{shop}->{amount} $item->{_source}->{shop}->{currency}\n";
      }
    }

  }
  sleep 5;
  $lasttime = $timestamp;
}

