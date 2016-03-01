#!/usr/bin/perl

# This is intended to be a script run ONCE to pull all of the statistics data from
# the fetch-stats table and load it into Elastic Search. After this, the get-forum-threads
# and refresh-forum-threads scripts should load new data into ES.
#
# There is no docid generation, so if this script is run multiple times it will result in
# duplicate data in ES
#
# NOTE: Since this is meant to be a one-time thing, a lot of this code is stolen from other
# bits, so some of the variables might not make much sense

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

$dbh = DBI->connect("dbi:mysql:$conf{dbName}","$conf{dbUser}","$conf{dbPass}") || die "DBI Connection Error: $DBI::errstr\n";

my $e = Search::Elasticsearch->new(
  cxn_pool => 'Sniff',
  nodes =>  [
    "$conf{esHost}:9200",
    "$conf{esHost2}:9200"
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
  type => "$conf{esRunStatsType}",
);

$pquery = "select * from `fetch-stats`";
$query_handle=$dbh->prepare($pquery);
$query_handle->{"mysql_use_result"} = 1;
$query_handle->execute();
$query_handle->bind_columns(undef, \$timestamp, \$forum, \$TotalRequests, \$TotalTransferKB, \$TotalUncompressedKB, \$ForumIndexPagesFetched, \$ShopPagesFetched, \$Errors, \$RunType, \$NewThreads, \$UnchangedThreads, \$UpdatedThreads, \$RunTime);
while($query_handle->fetch()) {
  my %data;
  $data{RunTimestamp} += $timestamp;
  $forum = "all" if ($forum eq "refresh");
  $data{Forum} = $forum;
  $data{TotalRequests} += $TotalRequests;
  $data{TotalTransferKB} += $TotalTransferKB;
  $data{ForumIndexPagesFetched} += $ForumIndexPagesFetched;
  $data{ShopPagesFetched} += $ShopPagesFetched;
  $data{Errors} += $Errors;
  $data{RunType} = $RunType;
  $data{NewThreads} += $NewThreads;
  $data{UnchangedThreads} += $UnchangedThreads;
  $data{UpdatedThreads} += $UpdatedThreads;
  $data{RunTime} += $RunTime;

  my $jsonout = JSON::XS->new->utf8->encode(\%data);
  $bulk->index({ source => "$jsonout" });
}
$bulk->flush;

&ExitProcess;
