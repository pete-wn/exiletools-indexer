#!/usr/bin/perl

use Search::Elasticsearch;
use DBI;
use JSON;
use JSON::XS;
use Encode;
use Data::Dumper;
use Time::HiRes;
use Parallel::ForkManager;
use utf8;
use Text::Unidecode;
require("subs/all.subroutines.pl");

&BuildUniqueInfoHash;

#print Dumper(%uniqueInfoHash);



sub BuildUniqueInfoHash {
  our %uniqueInfoHash;

  $el = Search::Elasticsearch->new(
    nodes =>  [
      "$conf{eshost}:9200"
    ]
  );

  my %search;
  $search{index} = "$conf{esindex}";
  $search{type} = "$conf{estype}";
  $search{body}{size} = 0;
  $search{body}{query}{bool}{filter}[0]{term}{"attributes.rarity"} = "Unique";
  $search{body}{query}{bool}{filter}[1]{term}{"attributes.identified"} = "True";
  $search{body}{aggs}{"Icons"}{terms}{field} = "info.icon";
  $search{body}{aggs}{"Icons"}{terms}{size} = 5000;
  $search{body}{aggs}{"Icons"}{terms}{min_doc_count} = 20;
  $search{body}{aggs}{"Icons"}{aggs}{"Names"}{terms}{field} = "info.name";
  $search{body}{aggs}{"Icons"}{aggs}{"Names"}{terms}{min_doc_count} = 20;
  $search{body}{aggs}{"Icons"}{aggs}{"Names"}{terms}{size} = 20;
  my $results = $el->search(%search);

  print "our \%uniqueInfoHash;\n";
  foreach $iconName (@{$results->{aggregations}->{Icons}->{buckets}}) {
    next if ($iconName->{key} =~ /Alt\.png/);
    foreach $itemName (@{$iconName->{Names}->{buckets}}) {
      next if ($itemName->{key} =~ /Agnerod/);
      print '$uniqueInfoHash{"'.$iconName->{key}.'"}="'.$itemName->{key}.'";'."\n";
      $uniqueInfoHash{$iconName->{key}} = $itemName->{key};
    }
  }
  print "return true;\n";
}
