#!/usr/bin/perl

$|=1;

use JSON;
use JSON::XS;
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);  
use Encode;
use utf8::all;
use Parallel::ForkManager;
use DBI;
use HTML::Tree;
use Date::Parse;
#use Unicode::Diacritic::Strip;
require("subs/all.subroutines.pl");
require("subs/sub.threadDataToDB.pl");

# == Initial Options 
# Whether or not to give basic debug output
$debug = 1;

# Whether or not to give SUPER VERBOSE output. USE WITH CARE! Will create huge logs
# and tons of spammy text.
$sv = 0;

# The number of processes to fork
$forkMe = 8;

# For debugging, the maximum number of threads to process before aborting
$maxProcess = 99999999999999999;
#$maxProcess = 1;

# == Initial Startup
&StartProcess;


#$dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";


# Initial start, to be cleaned up
# Get a list of all items in the queue that haven't been processed and push it into a hash based on the threadid and timestamp
@keyfields = ("threadid","timestamp");
%updateHash = %{$dbh->selectall_hashref("SELECT `threadid`,`timestamp`,`processed` FROM `shop-queue` WHERE `processed`<2",\@keyfields)};
$dbh->disconnect;

my $updateCount = (keys(%updateHash));
&d("Preparing to process $updateCount updates...\n");

my $manager = new Parallel::ForkManager( $forkMe );

#foreach $threadid(sort keys(%updateHash)) {
foreach $threadid(keys(%updateHash)) {
  $processcount++;
  last if ($processcount > $maxProcess);
  $manager->start and next;
    $dbhf = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";
    print "[$$] Processing THREAD $threadid ($processcount of $updateCount)\n";
    foreach $timestamp (sort keys(%{$updateHash{$threadid}})) {
      &LoadUpdate("$threadid","$timestamp");
    }
    $dbhf->disconnect;
  $manager->finish;
}
$manager->wait_all_children;
print localtime()." All Items Processed.\n";


# == Exit cleanly
&ExitProcess;

