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

# The depth to crawl each forum for updates
$maxCheckForumPages = 8;


my $time = localtime();
&d("Started at $time.\n");

&CreateLock("$ARGV");



exit;

$timestamp = time();
$dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";
$statement = $dbh->prepare("SELECT * FROM `league-list`");
$statement->execute;
$statement->bind_columns(undef, \$myleague, \$prettyName, \$apiName, \$startTime, \$endTime, \$active, \$itemjsonName, \$archivedLadder, \$shopForumURL, \$shopURL, \$shopForumID);
while ($statement->fetch()) {
  next if (($prettyName eq "Tempest") || ($prettyName eq "Warbands"));
  if (($active) && ($endTime > $timestamp) && ($startTime < $timestamp) && ($shopForumURL) && ($shopForumID) && ($shopURL)) {

#print "good: $myleague $shopForumURL $shopURL $shopForumID\n";

    $conf{$myleague}{url} = $shopForumURL;
    $conf{$myleague}{shopurl} =  $shopURL;
    $conf{$myleague}{id} = $shopForumID;
    $forumhash{$shopForumID} = $myleague;
  }
}
$dbh->disconnect;

my $ua = LWP::UserAgent->new;
my $can_accept = HTTP::Message::decodable;


$checkdays = 30;

# If we're told to fetch older posts, let's do that.

if ($ARGV[0] eq "old") {
  $checkdays = 45;
  print "** [OLD] Updating all thread data to find changes to items in the last 1 to $checkdays days\n";
  my $currenttime = time();
  # Last 15 Days
  my $starttime = $currenttime - (86400 * $checkdays);
  # To 48 hours ago
#  my $endtime = $currenttime - (86400 * 2);
  my $endtime = $currenttime - 86400;

  print "** [OLD] Pulling threads from $starttime to $endtime\n";

  $dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";
  %oldthreads = %{$dbh->selectall_hashref("SELECT `threadid`,`forumid`,`jsonfound`,`origin`,`processed`,max(`timestamp`) as time FROM `shop-threads` group by `threadid` LIMIT 1000",threadid)};
  $dbh->disconnect;
  foreach $thread (keys(%oldthreads)) {
    next unless ($oldthreads{$thread}{jsonfound});
    next unless ($oldthreads{$thread}{processed} == 2);
#    next unless ($oldthreads{$thread}{origin} ne "get-old-forum-threads");
#    next unless ($forumHash{$oldthreads{$thread}{forumid}});
    if (($oldthreads{$thread}{time} > $starttime) && ($oldthreads{$thread}{time} < $endtime)) {
      $gothreads{$thread}{forumid} = $oldthreads{$thread}{forumid};
    }
  }
  $gothreadcount = keys(%gothreads);
#  foreach $thread (keys(%gothreads)) {
#    print "  [ $threadcount / $gothreadcount ] $thread $gothreads{$thread}{forumid} $forumhash{$oldthreads{$thread}{forumid}}\n";
#  }

  my $manager = new Parallel::ForkManager( 2 );
  my $threadcount = 0;
  foreach $thread (keys(%gothreads)) {
    $threadcount++;
    $manager->start and next;
    $dbh = DBI->connect("dbi:mysql:$conf{dbtable}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";
    print "  [ $threadcount / $gothreadcount ] $thread $gothreads{$thread}{forumid}\n";
    &FetchShopPage("$thread","$forumhash{$oldthreads{$thread}{forumid}}");
    $dbh->disconnect;
    $manager->finish;
  }
  $manager->wait_all_children;
} elsif ($ARGV[0] eq "oldtemp") {
  $checkdays = 30;
  print "** [OLD TEMP] Updating TEMP League thread data to find changes to items in the $checkdays days\n";
  my $currenttime = time();
  # Last 15 Days
  my $starttime = $currenttime - (86400 * $checkdays);
  # To 12 hours ago
  my $endtime = $currenttime - 43200;

  print "** [OLD TEMP] Pulling threads from $starttime to $endtime\n";

  $dbh = DBI->connect("dbi:mysql:$conf{dbtable}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n"
;
  %oldthreads = %{$dbh->selectall_hashref("SELECT `threadid`,`forumid`,`jsonfound`,`origin`,`processed`,max(`timestamp`) as time FROM `shop-threads` WHERE `forumid`=\"597\" OR `forumid`=\"598\" group by `threadid` LIMIT 5000",threadid)};
  $dbh->disconnect;
  foreach $thread (keys(%oldthreads)) {
#    next unless ($oldthreads{$thread}{jsonfound});
#    next unless ($oldthreads{$thread}{processed} == 2);
#    next unless ($oldthreads{$thread}{origin} ne "get-old-forum-threads");
#    next unless ($forumHash{$oldthreads{$thread}{forumid}});
    if (($oldthreads{$thread}{time} > $starttime) && ($oldthreads{$thread}{time} < $endtime)) {
      $gothreads{$thread}{forumid} = $oldthreads{$thread}{forumid};
    }
  }
  $gothreadcount = keys(%gothreads);
#  foreach $thread (keys(%gothreads)) {
#    print "  [ $threadcount / $gothreadcount ] $thread $gothreads{$thread}{forumid} $forumhash{$oldthreads{$thread}{forumid}}\n";
#  }

  my $manager = new Parallel::ForkManager( 2 );
  my $threadcount = 0;
  foreach $thread (keys(%gothreads)) {
    $threadcount++;
    $manager->start and next;
    $dbh = DBI->connect("dbi:mysql:$conf{dbtable}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\
n";
    print "  [ $threadcount / $gothreadcount ] $thread $gothreads{$thread}{forumid}\n";
    &FetchShopPage("$thread","$forumhash{$oldthreads{$thread}{forumid}}");
    $dbh->disconnect;
    $manager->finish;
  }
  $manager->wait_all_children;

# Do normal update of pages
} elsif ($ARGV[0] eq "all") {
  $forum = $ARGV[1];
  die "must specify a forum\n" unless ($forum);
  $maxCheckForumPages = 10;
  $startCheckForumPages = 8;
  local $fullupdate = "go";

  print "Performing FULL scan of ALL pages for $forum\n";
  open(LOG,">>$logdir/get-forum-$forum.log");
  my $manager = new Parallel::ForkManager( 3 );
  for (my $page=$startCheckForumPages; $page <= $maxCheckForumPages; $page++) {
    if (-f "$abortfile") {
      print localtime()." Received abort notification via file that current page is too old to process!\n";
      $manager->wait_all_children;
      print localtime()." Finalized abort.\n";
      last;
    }
    $manager->start and next;
    $dbh = DBI->connect("dbi:mysql:$conf{dbtable}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";
    my $status = &FetchForumPage("$conf{$forum}{url}/$page","$conf{$forum}{id}");
    $dbh->disconnect;
    $manager->finish;
  }
  $manager->wait_all_children;
  close(LOG);
} else {
  my $manager = new Parallel::ForkManager( 3 );
  foreach $forum (keys(%conf)) {
    # FORK START
    $manager->start and next;

    open(LOG,">>$logdir/get-forum-$forum.log");
    $dbh = DBI->connect("dbi:mysql:$conf{dbtable}","$conf{dbpass}","$conf{dbuser}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";
    for (my $page=1; $page <= $maxCheckForumPages; $page++) {
      my $status = &FetchForumPage("$conf{$forum}{url}/$page","$conf{$forum}{id}");
      sleep 2;
    }
    $dbh->disconnect;
    close(LOG);
  
    # FORK DONE
    $manager->finish;
  }
  $manager->wait_all_children;
}




# End
unlink($lockfile);
unlink($abortfile);
my $time = localtime();
&d("Done at $time.\n");

exit;

# ==================================================================

sub d {
  print LOG "  ".$_[0] if ($debug);
  print "  ".$_[0] if ($debug);
}

sub FetchShopPage {
  my $target = $_[0];
  if ($_[1]) {
    $forum = $_[1];
  }
  my $targeturl = $conf{$forum}{shopurl}."/".$_[0];
  &d("FetchShopPage: $targeturl\n");
  my $threadid = $target;

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
  $dbh->do("UPDATE `web-post-track` SET
                 `lastedit`=\"$lastedit\",
                 `generatedWith`=\"$generatedWith\"
                 WHERE `threadid`=\"$threadid\"
                 ") || die "SQL ERROR: $DBI::errstr\n";

  $dbh->do("INSERT INTO `shop-threads` SET
                `threadid`=\"$threadid\",
                `timestamp`=\"$timestamp\",
                `processed`=\"$processed\",
                `forumid`=\"$forumID\",
                `jsonfound`=\"$jsonfound\",
                `origin`=\"get-forum-threads\"
                ") || die "SQL ERROR: $DBI::errstr\n";

  # Done saving local copy of data
  # =========================================
}


sub FetchForumPage {
  local $forumID = $_[1];
  local $forumPage = $_[0];
  &d("$$ FetchForumPage [$forumID]: $_[0] \n");

  my $response = $ua->get("$_[0]",'Accept-Encoding' => $can_accept);
#  print "Content Encoding is ".$response->header ('Content-Encoding')."\n";
#  print length($response->content)." bytes received.\n";
#  print length($response->decoded_content)." bytes unpacked.\n";
  my $content = $response->decoded_content;
  my $htmltree = HTML::Tree->new();
  $htmltree->parse($content);
  my $clean = $htmltree->as_HTML;
  $clean =~ s/<tr/\n<tr/g;

  my $status;
  
  my @content = split(/\n/, $clean);
  foreach $line (@content) {
    if ($line =~ /<div class=\"sticky off\"/) {
      # Skip Locked Threads
      next if ($line =~ /<div class=\"locked\">/);
      my $threadid;
      my $threadtitle;
      my $username;
      my $lastpost;
      my $originalpost;
      my $viewcount;
      my $replies;
      my $lastpostepoch;
  
      if ($line =~ /<div class=\"title\"><a href=\"\/forum\/view-thread\/(\d+)\">(.*?)<\/a>/) {
        $threadid = $1;
        $threadtitle = $2; 
      }
      if ($line =~ /span class=\"post_date\"> on (.*?)<\/span><\/div>/) {
        $originalpost = str2time($1);
      }
      if ($line =~ /<td class=\"views\">(.*?)<\/td>/) {
        $viewcount = $1;
      }
      if ($line =~ /<td class="replies">(.*?)<\/td>/) {
        $replies = $1;
      }
      if ($line =~ /<a href="\/account\/view-profile\/(.*?)">/) {
        $username = $1;
      }
      if ($line =~ /<td class="last_post">.*?<span class=\"post_date\"> on (.*?)<\/span/) {
        # time is UTC
        $lastpost = $1;
        $lastpostepoch = str2time($lastpost);
      }
      if ($line =~ /<h3 class=\"strip-heading centered\">No Threads<\/h3>/) {
        $abortme = "no threads!";
      }

      $threadtitle =~ tr/a-zA-Z0-9 //dc;
  
      if ($threadid && $threadtitle && $username && $lastpost) {
        my $checkLast = $dbh->selectrow_array("select (`lastpost`) from `web-post-track` where `threadid`=\"$threadid\" limit 1");
        if (($lastpost ne "$checkLast") || ($performFullScan == 1)) {
          if ($checkLast) {
            &d("UPDATED: $forumPage | $threadid | $threadtitle | $username\n");
            &FetchShopPage("$threadid");
            $dbh->do("UPDATE `web-post-track` SET
              `lastpost`=\"$lastpost\",
              `username`=\"$username\",
              `originalpost`=\"$originalpost\",
              `views`=\"$viewcount\",
              `replies`=\"$replies\",
              `lastpostepoch`=\"$lastpostepoch\",
              `title`=\"$threadtitle\"
              WHERE `threadid`=\"$threadid\"
              ") || die "SQL ERROR: $DBI::errstr\n";

          } else {
            &d("NEW: $forumPage | $threadid | $threadtitle | $username\n");
            &FetchShopPage("$threadid");
            $dbh->do("INSERT INTO `web-post-track` SET
                `threadid`=\"$threadid\",
                `lastpost`=\"$lastpost\",
                `username`=\"$username\",
                `originalpost`=\"$originalpost\",
                `views`=\"$viewcount\",
                `replies`=\"$replies\",
                `lastpostepoch`=\"$lastpostepoch\",
                `title`=\"$threadtitle\"
                ") || die "SQL ERROR: $DBI::errstr\n";
          }
        } elsif ($fullupdate eq "go") {
          &d("$$ FORCE UPDATE: $forumPage | $threadid | $threadtitle | $username\n");
          &FetchShopPage("$threadid");
          $dbh->do("UPDATE `web-post-track` SET
            `lastpost`=\"$lastpost\",
            `username`=\"$username\",
            `originalpost`=\"$originalpost\",
            `views`=\"$viewcount\",
            `replies`=\"$replies\",
            `lastpostepoch`=\"$lastpostepoch\",
            `title`=\"$threadtitle\"
            WHERE `threadid`=\"$threadid\"
            ") || die "SQL ERROR: $DBI::errstr\n";
          my $currentepoch = time();
          if (($abortme) || ($currentepoch - $lastpostepoch) > ($checkdays * 86400)) {
            $abortme = "threads older than $checkdays" if (($currentepoch - $lastpostepoch) > ($checkdays * 86400));
            system("/bin/touch $abortfile");
            print "ABORTING BECAUSE: $forumPage $threadid $threadtitle $lastpostepoch (abortme: $abortme)\n";
          }

        } else  {
          &d("UNCHANGED: $forumPage | $threadid | $threadtitle | $username\n");
        }
      }
    }
  }
  return("$status");
}


