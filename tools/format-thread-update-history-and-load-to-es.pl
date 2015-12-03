#!/usr/bin/perl

# This is intended to be a script run ONCE to pull all of the statistics data from
# the thread-update-history table and load it into Elastic Search. After this, the get-forum-threads
# and refresh-forum-threads scripts should load new data into ES.
#
# There is no docid generation, so if this script is run multiple times it will result in
# duplicate data in ES
#
# NOTE: Since this is meant to be a one-time thing, a lot of this code is stolen from other
# bits, so some of the variables might not make much sense and it's kinda sloppy.

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

# == Initial Startup
&StartProcess;

$dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}") || die "DBI Connection Error: $DBI::errstr\n";

my $e = Search::Elasticsearch->new(
  cxn_pool => 'Sniff',
  nodes =>  [
    "$conf{eshost}:9200",
    "$conf{eshost2}:9200"
  ],
  # enable this for debug but BE CAREFUL it will create huge log files super fast
  # trace_to => ['File','/tmp/eslog.txt'],

  # Huge request timeout for bulk indexing
  request_timeout => 300
);

die "some error?"  unless ($e);

my $bulk = $e->bulk_helper(
  index => "$conf{esStatsIndex}",
  max_count => '5100',
  max_size => '0',
  type => "$conf{esThreadStatsType}",
);

$pquery = "select * from `thread-update-history`";
$query_handle=$dbh->prepare($pquery);
$query_handle->{"mysql_use_result"} = 1;
$query_handle->execute();
$query_handle->bind_columns(undef, \$threadid, \$updateTimestamp, \$itemsAdded, \$itemsRemoved, \$itemsModified, \$sellerAccount, \$sellerIGN, \$totalItems, \$buyoutCount, \$generatedWith, \$threadTitle);

while($query_handle->fetch()) {
  my %data;
  $data{threadid} = $threadid; # don't force this to be a number just in case
  $data{updateTimestamp} += $updateTimestamp;
  $data{itemsAdded} += $itemsAdded;
  $data{itemsRemoved} += $itemsRemoved;
  $data{itemsModified} += $itemsModified;
  $data{sellerAccount} = $sellerAccount;
  $data{sellerIGN} = $sellerIGN;
  $data{totalItems} += $totalItems;
  $data{buyoutCount} += $buyoutCount;
  $data{generatedWith} = $generatedWith;
  $data{threadTitle} = $threadTitle;
  
  my $id = $data{threadid}.$data{updateTimestamp};
  my $jsonout = JSON::XS->new->utf8->encode(\%data);
  $bulk->index({ id => "$id",  source => "$jsonout" });
}
$bulk->flush;

&ExitProcess;
