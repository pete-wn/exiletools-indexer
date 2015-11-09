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
require("subs/all.subroutines.pl");

# == Initial Options 
# Whether or not to give basic debug output
$debug = 1;

# Whether or not to give SUPER VERBOSE output. USE WITH CARE! Will create huge logs
# and tons of spammy text.
$sv = 1;

# The depth to crawl each forum for updates
$maxCheckForumPages = 1;

# The number of processes to fork
$forkMe = 1;

# The time to sleep between each page get
$sleepFor = 2;

# == Initial Startup
&StartProcess;

# Some hard coded variables for testing
$forums{darkshrine}{forumURL} = "http://www.pathofexile.com/forum/view-forum/597/page";
$forums{darkshrine}{forumID} = "597";
$forums{darkshrinehc}{forumURL} = "http://www.pathofexile.com/forum/view-forum/598/page";
$forums{darkshrinehc}{forumID} = "598";

# Create a user agent
my $ua = LWP::UserAgent->new;
# Make sure it accepts gzip
my $can_accept = HTTP::Message::decodable;

# Terminate our DB connection since we're going to do some weird forking
$dbh->disconnect if ($dbh->ping);

# Fork a new process for each forum to scan, up to a max of $forkMe processes
my $manager = new Parallel::ForkManager( $forkMe );
foreach $forum (keys(%forums)) {
  # FORK START
  $manager->start and next;

  # Prepare the local statistics hash
  local %stats;

  # On fork start, we must create a new DB Connection
  $dbhf = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";

  # Every $sleepFor seconds, iterate from page 1 to $maxCheckForumPages on the forums for the shop
  # This subroutine will grab the forum page and look for updates, calling FetchShopPage for any
  # it notices need to be updated
  for (my $page=1; $page <= $maxCheckForumPages; $page++) {
    my $status = &FetchForumPage("$forums{$forum}{forumURL}/$page","$forums{$forum}{forumID}","$forum");
    sleep $sleepFor;
  }

  # Disconnect forked DB connection
  $dbhf->disconnect if ($dbhf->ping);

  # Output some stats for this fork
  foreach $stat (sort(keys(%stats))) {
    &d("STATS: (PID: $$) [$forum] $stat: $stats{$stat}\n");
  }

  # FORK DONE
  $manager->finish;
}
$manager->wait_all_children;

# == Exit cleanly
&ExitProcess;

# ==================================================================

sub FetchShopPage {
  my $target = $_[0];
  if ($_[1]) {
    $forum = $_[1];
  }
  my $targeturl = $conf{$forum}{shopurl}."/".$_[0];
  &d("FetchShopPage: $targeturl\n");
  my $threadid = $target;

  # Return for now, don't do anything, for debugging
  return;

  # =========================================
  # Saving local copy of data
  my $timestamp = time();
  my $response = $ua->get("$targeturl",'Accept-Encoding' => $can_accept);
  my $content = $response->decoded_content;

  # Retry if the content is crap
  unless ($response->is_success) {
    print $response->decoded_content;  # or whatever
    print "WARNING: HTTP Error Received: ".$response->decoded_content." - Trying again\n";
    sleep 1;
    $response = $ua->get("$targeturl",'Accept-Encoding' => $can_accept);
    $content = $response->decoded_content;
    unless ($response->is_success) {
      print "ERROR: HTTP Error Recieved Twice: ".$response->decoded_content." (for $targeturl $threadid) Skipping.\n";
      return;
    }
  }

  system("mkdir -p $datadir/$target/raw") unless (-d "$datadir/$target/raw");
  open(RAW, ">$datadir/$target/raw/$timestamp.html") || die "ERROR opening $datadir/$target/raw/$timestamp.html - $1\n";
#  &d("  RAW HTML: $datadir/$target/raw/$timestamp.html\n");
  print RAW $content;
  close(RAW);
  my $jsonfound;
  my $generatedWith;

  if ($content =~ /require\(\[\"PoE\/Item\/DeferredItemRenderer\"\], function\(R\) \{ \(new R\((.*?)\)\)\.run\(\)\; \}\)\;/) {
    $rawjson = $1;
#    &d("  JSON found in $target\n");
    $jsonfound = 1;
  } else {
    &d("  WARNING: No JSON found in $target\n");
    $jsonfound = 0;
  }
  my $processed;
  if ($jsonfound > 0) {
    $processed = "0";
  } else {
    $processed = "5";
  }

  my $lastedit;
  if ($content =~ /Last edited by (.*?) on (.*?)<\/div/) {
    $lastedit = str2time($2);
  }
  if ($content =~ /i.imgur.com\/ZHBMImo.png/) {
    $generatedWith = "Procurement";
  }
  $dbhf->do("UPDATE `web-post-track` SET
                 `lastedit`=\"$lastedit\"
                 WHERE `threadid`=\"$threadid\"
                 ") || die "FATAL DBI ERROR: $DBI::errstr\n";

  $dbhf->do("INSERT INTO `shop-threads` SET
                `threadid`=\"$threadid\",
                `timestamp`=\"$timestamp\",
                `processed`=\"$processed\",
                `forumid`=\"$forumID\",
                `jsonfound`=\"$jsonfound\",
                `origin`=\"get-forum-threads\"
                ") || die "FATAL DBI ERROR: $DBI::errstr\n";

  # Done saving local copy of data
  # =========================================
}


sub FetchForumPage {
  local $forumPage = $_[0];
  local $forumID = $_[1];
  local $forumName = $_[2];
  &d("FetchForumPage: (PID: $$) [$forumName] $_[0] \n");

  my $response = $ua->get("$_[0]",'Accept-Encoding' => $can_accept);

  $stats{TotalRequests}++;
  $stats{TotalTransferBytes} += length($response->content);
  $stats{TotalUncompressedBytes} += length($response->decoded_content);

# Sometimes you don't even want to see stuff in Super Verbose ^_^
#  &sv("Content Encoding is ".$response->header ('Content-Encoding')."\n");
#  &sv("".length($response->content)." bytes received.\n");
#  &sv("".length($response->decoded_content)." bytes unpacked.\n");

  # Decode the returned data
  my $content = $response->decoded_content;

  # Parse the HTML into a tree for scanning
  my $tree = HTML::Tree->new();
  $tree->parse($content);

  # Look for the forumTable which has the posts
  my $table = $tree->look_down('_tag' => 'table', 'class' => 'forumTable viewForumTable');
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

      if ($class eq "views") {
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
          &d(" >ThreadInfo: (PID: $$) [$forum] UPDATED: $threadid | $threadtitle | $username | $lastpost | $lastpostepoch | $originalpost | $viewcount | $replies\n");
          &FetchShopPage("$threadid");
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
        # Otherwise this is a new thread
        } else {
          &d(" >ThreadInfo: (PID: $$) [$forum] NEW: $threadid | $threadtitle | $username | $lastpost | $lastpostepoch | $originalpost | $viewcount | $replies\n");
          &FetchShopPage("$threadid");
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
        }
      # If a fullupdate is forced, do this anyway
      } elsif ($fullupdate eq "go") {
        &d("$$ FORCE UPDATE: $forumPage | $threadid | $threadtitle | $username\n");
        &FetchShopPage("$threadid");
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
        my $currentepoch = time();
        if (($abortme) || ($currentepoch - $lastpostepoch) > ($checkdays * 86400)) {
          $abortme = "threads older than $checkdays" if (($currentepoch - $lastpostepoch) > ($checkdays * 86400));
          system("/bin/touch $abortfile");
          print "ABORTING BECAUSE: $forumPage $threadid $threadtitle $lastpostepoch (abortme: $abortme)\n";
        }
      # Else we already have the latest copy of this thread in the DB so do nothing
      } else  {
        &d(" >ThreadInfo: (PID: $$) [$forum] UNCHANGED: $threadid | $threadtitle | $username | $lastpost | $lastpostepoch | $originalpost | $viewcount | $replies\n");
      }
    }
  }
  return("$status");
}


