#!/usr/bin/perl

$|=1;

use LWP::UserAgent;
use Data::Dumper;
use HTML::Tree;
use JSON;
use JSON::XS;
use Encode;
use utf8::all;
use Parallel::ForkManager;
use Date::Parse;
use File::Path;
use Search::Elasticsearch;
require("subs/all.subroutines.pl");
require("subs/sub.threadDataToDB.pl");
require("subs/sub.getThreadFromForum.pl");

# == Initial Options 
# Whether or not to give basic debug output
$debug = 1;

# Whether or not to give SUPER VERBOSE output. USE WITH CARE! Will create huge logs
# and tons of spammy text.
$sv = 0;

if ($ARGV[0] =~ /\d+/) {
  $threadid = $ARGV[0];
} else {
  die "ERROR: You must specify a threadid to verify.\n";
}

# == Initial Startup
&StartProcess;

# Create a user agent
our $ua = LWP::UserAgent->new;
# Make sure it accepts gzip
our $can_accept = HTTP::Message::decodable;

# Create a database filehandle, we use dbhf because the subroutine assumes we will
# be called from a forked dbh from get-forum-threads
$dbhf = DBI->connect("dbi:mysql:$conf{dbName}","$conf{dbUser}","$conf{dbPass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";

# New ElasticSearch Connection also
$e = Search::Elasticsearch->new(
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

my $status = &FetchShopPage("$threadid");

$dbhf->disconnect;
# == Exit cleanly
&ExitProcess;

