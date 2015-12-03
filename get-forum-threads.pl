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
use Time::HiRes qw(usleep); 
use Search::Elasticsearch;

require("subs/all.subroutines.pl");
require("subs/sub.threadDataToDB.pl");
require("subs/sub.getThreadFromForum.pl");

# == Initial Startup
&StartProcess;

# == Initial Options 
# The depth to crawl each forum for updates
if ($args{maxpages}) {
  $maxCheckForumPages = $args{maxpages};
} else {
  $maxCheckForumPages = 8;
}

# The number of processes to fork
if ($args{forks}) {
  $forkMe = $args{forks};
} else {
  $forkMe = 4;
}

# Microseconds to sleep for between page requests to avoid excessive requests
if ($args{sleep}) {
  $sleepFor = $args{sleep} * 1000;
} else {
  $sleepFor = 600 * 1000;
}

# This tells fetch-stats what time of stats run this was
$runType = "normal";


# Terminate our DB connection since we're going to do some weird forking
$dbh->disconnect if ($dbh->ping);

# Fork a new process for each forum to scan, up to a max of $forkMe processes
my $manager = new Parallel::ForkManager( $forkMe );
foreach $forum (keys(%activeLeagues)) {

  # If only a single forum is specified, skip all other forums
  if ($args{forum}) {
    next unless ($forum eq $args{forum});
  }


  # FORK START
  $manager->start and next;

  # log the start time for this run
  local $runStartTime = time();

  # Create a user agent
  our $ua = LWP::UserAgent->new;
  # Make sure it accepts gzip
  our $can_accept = HTTP::Message::decodable;
  # Prepare the local statistics hash
  local %stats;

  # On fork start, we must create a new DB Connection
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

  # Every $sleepFor seconds, iterate from page 1 to $maxCheckForumPages on the forums for the shop
  # This subroutine will grab the forum page and look for updates, calling FetchShopPage for any
  # it notices need to be updated
  for (my $page=1; $page <= $maxCheckForumPages; $page++) {
    my $status = &FetchForumPage("$activeLeagues{$forum}{shopForumURL}/$page","$activeLeagues{$forum}{shopForumID}","$forum");
    if ($status eq "Maintenance") {
      &d("FetchForumPage: (PID: $$) [$forum] WARNING: Got maintenance message, cancelling this run!\n");
      $stats{Errors}++;
      last;
    }
    usleep($sleepFor);
  }

  # Output some statistics from the run
  &OutputRunStats;

  # Disconnect forked DB connection
  $dbhf->disconnect if ($dbhf->ping);

  # FORK DONE
  $manager->finish;
}
$manager->wait_all_children;

# Find abandoned items that haven't been updated (hence seen by the indexer) recently and 
# update them, setting the verified status to OLD

my $days = 7; # Number of days after which an item is considered OLD
my $agelimit = time() - (86400 * $days); # Epoch time for old based on $days
my $oldcount = "0";

# Reconnect to DB
$dbh = DBI->connect("dbi:mysql:$conf{dbName}","$conf{dbUser}","$conf{dbPass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";

# This may be a big query sometimes, so instead of loading the entire thing into
# memory we'll just iterate on it
$query = "select `uuid`,`updated` from `items` where `updated`<$agelimit and `verified`=\"yes\"";
$query_handle = $dbh->prepare($query);
&d("Marking verified items that haven't been updated in $days days as OLD...\n");

# Execute the query and bind the variables
$query_handle->execute();
$query_handle->bind_columns(undef, \$uuid, \$updated);
while($query_handle->fetch()) {
      &sv(" $uuid too old, modifying verification\n");  
      # Mark the item has updated 7 days after it was abandoned instead of the current time
      my $modtimestamp = $updated + (86400 * $days);
      $dbh->do("UPDATE \`items\` SET
                updated=\"$modtimestamp\",
                verified=\"OLD\",
                inES=\"no\"
                WHERE uuid=\"$uuid\"
                ") || die "SQL ERROR: $DBI::errstr\n";
      $oldcount++;
}
&d(" > $oldcount abandonded items marked as OLD!\n");
$dbh->disconnect;

# == Exit cleanly
&ExitProcess;

# ==================================================================

sub FetchForumPage {
  local $forumPage = $_[0];
  local $forumID = $_[1];
  local $forumName = $_[2];
  &d("FetchForumPage: (PID: $$) [$forumName] $_[0] \n");

  my $response = $ua->get("$_[0]",'Accept-Encoding' => $can_accept);

  $stats{TotalRequests}++;
  $stats{TotalTransferBytes} += length($response->content);
  $stats{TotalUncompressedBytes} += length($response->decoded_content);
  $stats{ForumIndexPagesFetched}++;

# Sometimes you don't even want to see stuff in Super Verbose ^_^
#  &sv("Content Encoding is ".$response->header ('Content-Encoding')."\n");
#  &sv("".length($response->content)." bytes received.\n");
#  &sv("".length($response->decoded_content)." bytes unpacked.\n");

  # Decode the returned data
  my $content = $response->decoded_content;

  # Check for Maintenance message
  if ($content =~ /pathofexile.com is currently down for maintenance. Please try again later/) {
    return("Maintenance");
  }

  # Parse the HTML into a tree for scanning
  my $shoptree = HTML::Tree->new();
  $shoptree->parse($content);

  # Look for the forumTable which has the posts
  my $table = $shoptree->look_down('_tag' => 'table', 'class' => 'forumTable viewForumTable');
  # Start looking at each row of the table by finding the tr tag
  foreach my $row ($table->find_by_tag_name('tr')) {
    # Check the TR class and skip if it's heading
    my $trclass = $row->attr('class');
    # (I use a regexp instead of a perfect match in case sometimes there are multiple classes
    next if ($trclass =~ /heading/);

    # Make sure none of these variables are set outside this iteration
    my $threadid;
    my $threadtitle;
    my $username;
    my $lastpost;
    my $originalpost;
    my $viewcount;
    my $replies;
    my $lastpostepoch;

# For debug/programming purposes, ignore
#    print $row->as_HTML."\n";

    # Look at each column in the table by finding the td tag
    foreach my $column ($row->find_by_tag_name('td')) {
      my $class = $column->attr('class');

      # Populate variables based on known values - this is done in an if/else
      # loop instead of a direct loop in case the ordering changes, might not be
      # the best idea but oh well.

      # Search to see if this is a sticky thread and ignore it if so
      if ($class eq "flags first") { 
        if ($column->as_HTML =~ /\<div class=\"sticky\"\>/) {
          # This is a sticky thread, abort the iteration of these columns
          last;
        }
      } elsif ($class eq "views") {
        $viewcount = $column->as_text;
      } elsif ($class eq "replies") {
        $replies = $column->as_text;
      } elsif ($class eq "last_post") {

        # We review the last post section to see when this thread was last bumped.
        # The only thing we care about here is in the post_date span
        my $post_date = $column->look_down('_tag' => 'span', 'class' => 'post_date');
        $lastpost = $post_date->as_text;
        # Strip the " on " at the beginning
        $lastpost =~ s/^ on //;
        # use the str2time subroutine to convert this UTC field into an epoch timestamp
        $lastpostepoch = str2time($lastpost);

      } elsif ($class eq "thread") {

        # Thread data section including the threadid, threadtitle, username, and originalpost date
        # The HTML here is a bit messy. The thread class contains a lot of information by div:
        #
        # * title: contains the a href and thread name
        # * postBy: bunch of crap. includes two spans we care about, "profile link post_by_account achieved" for the
        #          account name and post_date for the post date
        # setReadButton: don't care
        # clear: don't care
        # status: contains read/unread status, don't care
 
        my $scan = $column->look_down('_tag' => 'div', 'class' => 'title');
        # The only text in scan right now is the shop name, so let's set that
        $threadtitle = $scan->as_text;
        # Find the threadid via regexp, seems like the only way to do this since we don't want
        # the entire href location
        $scan->as_HTML =~ /<a href=\"\/forum\/view-thread\/(.*?)\">/;
        $threadid = $1;

        # Scan for profile-link and post_date only in the postBy section
        my $scan = $column->look_down('_tag' => 'div', 'class' => 'postBy', sub {
          # The profile span can have a bunch of different classes but should include profile-link
          my $profile = $_[0]->look_down('_tag' => 'span', 'class' => qr/profile-link/);
          $username = $profile->as_text;
          # Set the original post date from the post_date spawn
          my $post_date = $_[0]->look_down('_tag' => 'span', 'class' => 'post_date');
          $originalpost = $post_date->as_text;
          # Remove the leading " on " from originalpost
          $originalpost =~ s/^ on //;
          # Convert originalpost into epoch time
          $originalpost = str2time($originalpost);
        });


      }

    }

    # I remove most special characters from thread titles because I find random
    # unicode characters to be very annoying, plus it means I don't have to worry
    # about sanitizing for SQL/ES injection
    # (~~~!! MY SHOP!!! ~~~~ `````` #@@@@!!!) seriously? eck.
    $threadtitle =~ tr/\'\(\)a-zA-Z0-9 //dc;

    # Some of the data in these variables may have leading or trailing spaces due to extra formatting
    # Let's remove them just in case, we don't want that
    $threadid =~ s/(^\s+|\s+$)//g;
    $threadtitle =~ s/(^\s+|\s+$)//g;
    $username =~ s/(^\s+|\s+$)//g;
    $lastpost =~ s/(^\s+|\s+$)//g;
    $lastpostepoch =~ s/(^\s+|\s+$)//g;
    $originalpost =~ s/(^\s+|\s+$)//g;
    $viewcount =~ s/(^\s+|\s+$)//g;
    $replies =~ s/(^\s+|\s+$)//g;

    # If we have all the relevant information populated, compare it against the database to decide what to do  
    # We don't just assume everything is good to avoid populating with incomplete data

    if ($threadid && $threadtitle && $username && $lastpost) {
      # Check the lastpost information in the DB to see if we've already tracked this edit/post
      my $checkLast = $dbhf->selectrow_array("select `lastpost` from `web-post-track` where `threadid`=\"$threadid\" limit 1");
      # If the current lastpost is different than the stored last post, fetch the thread and update the database
      if ($lastpost ne "$checkLast") {
        # If we've seen this thread before, then this is a thread update
        if ($checkLast) {
          &d(" > ThreadInfo: (PID: $$) [$forum] UPDATED: $threadid | $threadtitle | $username | $lastpost | $lastpostepoch | $originalpost | $viewcount | $replies\n");
          my $status = &FetchShopPage("$threadid");
          unless ($status eq "fail") {
            $dbhf->do("UPDATE `web-post-track` SET
                      `lastpost`=\"$lastpost\",
                      `username`=\"$username\",
                      `originalpost`=\"$originalpost\",
                      `views`=\"$viewcount\",
                      `replies`=\"$replies\",
                      `lastpostepoch`=\"$lastpostepoch\",
                      `title`=\"$threadtitle\"
                      WHERE `threadid`=\"$threadid\"
                      ") || die "FATAL DBI ERROR: $DBI::errstr\n";
            $stats{UpdatedThreads}++;
          }
          usleep($sleepFor);
        # Otherwise this is a new thread
        } else {
          &d(" > ThreadInfo: (PID: $$) [$forum] NEW: $threadid | $threadtitle | $username | $lastpost | $lastpostepoch | $originalpost | $viewcount | $replies\n");
          my $status = &FetchShopPage("$threadid");
          unless ($status eq "fail") {
            $dbhf->do("INSERT INTO `web-post-track` SET
                      `threadid`=\"$threadid\",
                      `lastpost`=\"$lastpost\",
                      `username`=\"$username\",
                      `originalpost`=\"$originalpost\",
                      `views`=\"$viewcount\",
                      `replies`=\"$replies\",
                      `lastpostepoch`=\"$lastpostepoch\",
                      `title`=\"$threadtitle\"
                      ") || die "FATAL DBI ERROR: $DBI::errstr\n";
            $stats{NewThreads}++;
          }
          usleep($sleepFor);
        }
      # If a fullupdate is forced, do this anyway
      } elsif ($fullupdate eq "go") {
        &d("$$ FORCE UPDATE: $forumPage | $threadid | $threadtitle | $username\n");
        my $status = &FetchShopPage("$threadid");
        unless ($status eq "fail") {
          $dbhf->do("UPDATE `web-post-track` SET
                    `lastpost`=\"$lastpost\",
                    `username`=\"$username\",
                    `originalpost`=\"$originalpost\",
                    `views`=\"$viewcount\",
                    `replies`=\"$replies\",
                    `lastpostepoch`=\"$lastpostepoch\",
                    `title`=\"$threadtitle\"
                    WHERE `threadid`=\"$threadid\"
                    ") || die "FATAL DBI ERROR: $DBI::errstr\n";
        }
        usleep($sleepFor);
        # Need to update this abort code
        my $currentepoch = time();
        if (($abortme) || ($currentepoch - $lastpostepoch) > ($checkdays * 86400)) {
          $abortme = "threads older than $checkdays" if (($currentepoch - $lastpostepoch) > ($checkdays * 86400));
          system("/bin/touch $abortfile");
          print "ABORTING BECAUSE: $forumPage $threadid $threadtitle $lastpostepoch (abortme: $abortme)\n";
        }
      # Else we already have the latest copy of this thread in the DB so do nothing
      } else  {
        &sv(" > ThreadInfo: (PID: $$) [$forum] UNCHANGED: $threadid | $threadtitle | $username | $lastpost | $lastpostepoch | $originalpost | $viewcount | $replies\n");
        $stats{UnchangedThreads}++;
      }
    }
  }
  return("$status");
}


