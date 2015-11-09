#!/usr/bin/perl

$|=1;

$develop = 1;
$debug = 1;
$sv = 0;

#binmode STDOUT, ':utf8';
use LWP::Simple qw($ua get);
use JSON;
use JSON::XS;
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);  
use Encode;
use utf8::all;
use YAML::Tiny;
use Parallel::ForkManager;
require("/pwxdata/poe/subs/global.subroutines.pl");
use DBI;


$datadir = "/pwxdata/poe/shops/data/threads";

$lockfile = "/pwxdata/poe/shops/logs/.lock-load-data";
if (-f $lockfile) {
  print "$time FATAL: Lock file exists. Exiting.\n";
  open(MAIL, "|/usr/sbin/sendmail -t");
  print MAIL "To: pete\@pwx.me\n";
  print MAIL "From: exiletools <pete\@exiletools.com>\n";
  print MAIL "Subject: Lock File Exists for Load Data\n\n";
  print MAIL "$time - A lock file still exists for load-data-from-disk.pl, possible problem/slow processing?\n";
  close(MAIL);
  die;
} else {
  system("touch $lockfile");
}


$dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";
@keyfields = ("threadid","timestamp");
%updateHash = %{$dbh->selectall_hashref("SELECT `threadid`,`timestamp`,`processed` FROM `shop-threads` WHERE `processed`<2 and `jsonfound`=1",\@keyfields)};
$dbh->disconnect;

my $updateCount = (keys(%updateHash));
print localtime()." Preparing to process $updateCount updates...\n";

my $manager = new Parallel::ForkManager( 8 );

foreach $threadid(sort keys(%updateHash)) {
  $processcount++;
#  last if ($processcount > 32);
  $manager->start and next;
    $dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";
    print "Processing THREAD $threadid ($processcount of $updateCount)\n";
    foreach $timestamp (sort keys(%{$updateHash{$threadid}})) {
      &ProcessUpdate("$threadid","$timestamp");
    }
    $dbh->disconnect;
  $manager->finish;
}


$manager->wait_all_children;
print localtime()." All Items Processed.\n";
unlink($lockfile);

exit;

# == SUBROUTINES ===============================================

sub d {
  print $_[0] if ($debug);
}

sub ProcessUpdate {
  local $threadid = $_[0];
  local $timestamp = $_[1];
  local $datadir = "$datadir/$threadid";
  local $content;
  local $data;
  my $activeFragment;
  my %spoilerActive;
  my $sellerAccount;
  my $sellerIGN;
  my $forumID;
  my $generatedWith;
  my $rawjson;

#  &d("ProcessUpdate: $forum $threadid $timestamp\n") if ($develop); 
  $dbh->do("UPDATE `shop-threads` SET
                 processed=\"1\"
                 WHERE `threadid`=\"$threadid\" AND `timestamp`=\"$timestamp\"
                 ") || die "SQL ERROR: $DBI::errstr\n";

  undef @content;
  if (-f "$datadir/raw/$timestamp.html") {
#    &d("  Found $datadir/raw/$timestamp.html\n");
    my $parseActive;
    open(IN, "$datadir/raw/$timestamp.html") || die "ERROR unable to open $datadir/raw/$timestamp.html - $!\n";
    while(<IN>) {
      my $line = $_;
      chomp($line);

      if ($line =~ /<input type=\"hidden\" name=\"forums\[0\]\" value=\"(\d+)\" id=\"forums-0\">/) {
        $forumID = $1;
      } elsif ($line =~ /i\.imgur\.com\/ZHBMImo\.png/) {
        $generatedWith = "Procurement";
#      } elsif ($line =~ /cldly.com\/pathofexile/) {
#        $generatedWith = "Storefront"; 
      } elsif ($line =~ /href=\"\/account\/view-profile\/(.*?)\"/) {
        $sellerAccount = $1;
      } elsif ($line =~ /<h1 class=\"topBar last layoutBoxTitle\">(.*?)<\/h1>/) {
        $threadTitle = $1;
      }
      if ($parseActive) {
        if ($line =~ /IGN:?\s+(?:is\s+)?(\S+?)(\s+|<|\.)/) {
          $sellerIGN = $1;
        }
        undef $parseActive if ($line =~ /<div class="post_anchor"/);
        push @content, $line;
      } elsif ($line =~ /<div id="mainContainer" class="boxLayout">/) {
        $parseActive = 1;
      }

      if ($line =~ /require\(\[\"PoE\/Item\/DeferredItemRenderer\"\], function\(R\) \{ \(new R\((.*?)\)\)\.run\(\)\; \}\)\;/) {
        $rawjson = $1;
      }
    }
    close(IN);
  } else {
    &d("WARNING: HTML data not found for $datadir/raw/$timestamp.html - possible ERROR. Skipping.\n");
    $dbh->do("UPDATE `shop-threads` SET
                   processed=\"5\",
                   jsonfound=\"0\",
                   forumID=\"$forumID\"
                   WHERE `threadid`=\"$threadid\" AND `timestamp`=\"$timestamp\"
                   ") || die "SQL ERROR: $DBI::errstr\n";
    return;
  }

  unless ($rawjson) {
    &d("  WARNING: JSON data not found in $datadir/raw/$timestamp.html - possible empty update. Skipping.\n");
    $dbh->do("UPDATE `shop-threads` SET
                   processed=\"5\",
                   jsonfound=\"0\",
                   forumID=\"$forumID\"
                   WHERE `threadid`=\"$threadid\" AND `timestamp`=\"$timestamp\"
                   ") || die "SQL ERROR: $DBI::errstr\n";
    return;
  }

  $content = join("", @content);
  
  unless ($content && $rawjson) {
    print "! ERROR [$threadid][$timestamp]: content / rawjson not working\n";
    return;
  }

  # Remove funky <<set formatting from raw json
  $rawjson =~ s/\<\<set:(\S+?)\>\>//g;
  
  $data = decode_json(encode("utf8", $rawjson));
  
  local $itemsAdded;
  local $itemsRemoved;
  local $itemsModified;
  local $itemsUpdated;
  local $buyoutCount;
  local $totalItems;

  $content =~ tr/\x80-\xFF//d;
  $content =~ s/\s+/ /g;
  $content =~ s/<br \/>//g;
  $content =~ s/<div/\n<div/g;

  my @content = split(/\n/, $content);
  foreach my $line (@content) {
    if ($line =~ /div class=\"itemFragment.*id=\"item-fragment-(\d+)\"/) {
      $activeFragment = $1;

      if ($line =~ /(?:\~|>|-|\`| )(b\/o|price)\s+((?:\d+)*(?:(?:\.|\,)\d+)?)\s*([A-Za-z]+)/) {
        &ProcessItemFragment("$activeFragment", "$1", "$2", "$3", "0", "$threadid", "$timestamp", "$line");
        undef($activeFragment);

        # just in case this was the last item in a spoiler with a buyout
        if ($spoilerActive{type} && $line =~ /<\/div> <\/div>/) {
          &d("End of Spoiler: $line\n") if ($sv);
          undef %spoilerActive;
        }
        $buyoutCount++;
      } elsif ($spoilerActive{type}) {
        &ProcessItemFragment($activeFragment,$spoilerActive{type},$spoilerActive{amount},$spoilerActive{currency},"spoiler",$threadid,$timestamp);
        undef($activeFragment);
        if ($line =~ /<\/div> <\/div>/) {
          &d("End of Spoiler: $line\n") if ($sv);
          undef %spoilerActive;
        }
        $buyoutCount++;
      } elsif ($line =~ /\~gb\/o/) {
        print "[$threadid] [$timestamp] WARNING: Global Buyout Ignored: $line\n";
      } elsif ($line =~ /(b\/o|\~price)/) {
        print "[$threadid] [$timestamp] WARNING: Unmatched buyout: \'$line\'\n";
      } else {
        &ProcessItemFragment("$activeFragment","","","","", "$threadid", "$timestamp", "$line");
      }
    } elsif ($line =~ /<div class=\"spoilerTitle\"><span>.*?(?:\~|>| )(b\/o|price)\s+((?:\d+)*(?:(?:\.|,)\d+)?)\s*([A-Za-z]+)/) {
      $spoilerActive{type} = $1;
      $spoilerActive{amount} = $2;
      $spoilerActive{currency} = $3;
      &d("Start of Spoiler: [$1|$2|$3] $line\n") if ($sv);
    }
  }

  # Adding of items done, let's see what's different
  my $oldhash = $dbh->selectall_hashref("SELECT * FROM `thread-items` WHERE \`updated\`!=\"$timestamp\" AND \`threadid\`=\"$threadid\" AND \`verified\`!=\"GONE\"","uuid") || die "ERROR: $DBI::errstr\n";
  foreach my $uuid (keys(%{$oldhash})) {
    $dbh->do("UPDATE \`thread-items\` SET
              verified=\"GONE\",
              inES=\"no\"
              WHERE uuid=\"$uuid\"
              ") || die "SQL ERROR: $DBI::errstr\n";
    $itemsRemoved++;
  }
  
  $dbh->do("INSERT IGNORE INTO \`thread-update-history\` SET
            threadid=\"$threadid\",
            updateTimestamp=\"$timestamp\",
            itemsAdded=\"$itemsAdded\",
            itemsRemoved=\"$itemsRemoved\",
            itemsModified=\"$itemsModified\",
            sellerAccount=\"$sellerAccount\",
            sellerIGN=\"$sellerIGN\",
            totalItems=\"$totalItems\",
            buyoutCount=\"$buyoutCount\",
            forumID=\"$forumID\",
            generatedWith=\"$generatedWith\",
            threadTitle=\"$threadTitle\"
            ") || die "SQL ERROR: $DBI::errstr\n";


  $dbh->do("INSERT INTO \`thread-last-update\` VALUES
            (\"$threadid\",\"$timestamp\",\"$itemsAdded\",\"$itemsRemoved\",\"$itemsModified\",\"$sellerAccount\",\"$sellerIGN\",\"$totalItems\",\"$buyoutCount\",\"$forumID\",\"$generatedWith\",\"$threadTitle\")
            ON DUPLICATE KEY UPDATE
            threadid=\"$threadid\",
            updateTimestamp=\"$timestamp\",
            itemsAdded=\"$itemsAdded\",
            itemsRemoved=\"$itemsRemoved\",
            itemsModified=\"$itemsModified\",
            sellerAccount=\"$sellerAccount\",
            sellerIGN=\"$sellerIGN\",
            totalItems=\"$totalItems\",
            buyoutCount=\"$buyoutCount\",
            forumID=\"$forumID\",
            generatedWith=\"$generatedWith\",
            threadTitle=\"$threadTitle\"
            ") || die "SQL ERROR: $DBI::errstr\n";

  

#  &d("  forumID: $forumID | generatedWith: $generatedWith | sellerAccount: $sellerAccount | sellerIGN: $sellerIGN | $itemsAdded Added | $itemsRemoved Removed | $itemsModified Modified | $itemsUpdated Updated | $buyoutCount Buyouts Detected\n");

  $dbh->do("UPDATE `shop-threads` SET
                 processed=\"2\",
                 forumID=\"$forumID\"
                 WHERE `threadid`=\"$threadid\" AND `timestamp`=\"$timestamp\"
                 ") || die "SQL ERROR: $DBI::errstr\n";

}

sub ProcessItemFragment {
  my $activeFragment = $_[0];
  my $type = $_[1];
  my $amount = $_[2];
  $amount =~ s/\,/\./g;
  my $currency = $_[3];
  my $spoilertag = "[spoilertag] " if ($_[4] eq "spoiler");
  my $threadid = $_[5];
  my $timestamp = $_[6];

  my $debugline = $_[7];

  # Debug
#  print "activeFragment=\"$activeFragment\",type=\"$type\",amount=\"$amount\",currency=\"$currency\",spoilertag=\"$spoilertag\",threadid=\"$threadid\",timestamp=\"$timestamp\"\n";
#  print "debugLine=\"$debugline\"\n";


  my $jsonchunk = JSON->new->utf8;
  my $prettychunk = $jsonchunk->pretty->encode($data->[$activeFragment]->[1]);
  my $tightchunk = encode_json ($data->[$activeFragment]->[1]);
  local $md5sum = md5_hex($prettychunk);

  # Skip if it's a quest item
# Disabled because of divination cards, dammit.
#  return if ($data->[$activeFragment]->[1]{frameType} == 6); 

  # Don't update a record if the item isn't verified
  return unless ($data->[$activeFragment]->[1]{verified});

  my $standardCurrency;
#  $currency = lc($currency);
  if ($currencyName{$currency}) {
    $standardCurrency = $currencyName{$currency};
  } elsif ($currency) {
    $standardCurrency = "Unknown";
  } else{
    if ($amount) {
      print "WTF activeFragment=\"$activeFragment\",type=\"$type\",amount=\"$amount\",currency=\"$currency\",spoilertag=\"$spoilertag\",threadid=\"$threadid\",timestamp=\"$timestamp\"\n";
      print "WTF debugLine=\"$debugline\"\n";
      print "WTF \"$currency\"\n";
    }
    $standardCurrency = "NONE";
  }

  local $name;
  if (($data->[$activeFragment]->[1]{name}) && ($data->[$activeFragment]->[1]{typeLine})) {
    $name = $data->[$activeFragment]->[1]{name}." ".$data->[$activeFragment]->[1]{typeLine};
  } elsif ($data->[$activeFragment]->[1]{name}) {
    $name = $data->[$activeFragment]->[1]{name};
  } elsif ($data->[$activeFragment]->[1]{typeLine}) {
    $name = $data->[$activeFragment]->[1]{typeLine};
  }

  $name =~ s/Maelst(\S+?)m/Maelstrom/g;
  $name =~ s/Mj(\S+?)lnir/Mjolnir/g;
  $data->[$activeFragment]->[1]{name} =~ s/Maelst(\S+?)m/Maelstrom/g;
  $data->[$activeFragment]->[1]{name} =~ s/Mj(\S+?)lnir/Mjolnir/g;

  my $uuid = "$threadid:$md5sum";  

  my $threadshash = $dbh->selectrow_hashref("SELECT added,updated,modified,currency,amount FROM \`thread-items\` WHERE uuid=\"$uuid\" LIMIT 1");
  # Don't update a record if we already updated it
  if ($threadshash->{"updated"} == $timestamp) {
    return;
  }

  $totalItems++;

  if ($threadshash->{"added"} && (($threadshash->{"currency"} ne "$standardCurrency") || ($threadshash->{"amount"} != "$amount"))) {

    &d("[$threadid][$timestamp][MODIFIED] $activeFragment ($name) ($uuid) Currency Was ".$threadshash->{"amount"}." ".$threadshash->{"currency"}." | IS NOW $amount $standardCurrency\n") if ($sv);
    # This Item was MODIFIED
    $itemsModified++;
 
    my $chaosEquiv = &StandardizeCurrency("$amount","$standardCurrency");
    $chaosEquiv = "NULL" unless $chaosEquiv > 0;

    $dbh->do("UPDATE \`thread-items\` SET
              amount=\"$amount\",
              updated=\"$timestamp\",
              modified=\"$timestamp\",
              verified=\"$data->[$activeFragment]->[1]{verified}\",
              chaosEquiv=$chaosEquiv,
              currency=\"$standardCurrency\",
              inES=\"no\"
              WHERE uuid=\"$uuid\"
              ") || die "SQL ERROR: $DBI::errstr\n";

  } elsif ($threadshash->{"added"}) {
    # This item is simply updated
    $itemsUpdated++;
    &d("[$threadid][$timestamp][UPDATED] No change to $activeFragment ($name) ($uuid)\n") if ($sv);
    $dbh->do("UPDATE \`thread-items\` SET
              verified=\"$data->[$activeFragment]->[1]{verified}\",
              updated=\"$timestamp\",
              inES=\"no\"
              WHERE uuid=\"$uuid\"
              ") || die "SQL ERROR: $DBI::errstr\n";
  } else {
    # This Item was ADDED
    &d("[$threadid][$timestamp][ADDED] $activeFragment ($name) ($uuid) | $amount $standardCurrency\n") if ($sv);
    $itemsAdded++;
    my $chaosEquiv = &StandardizeCurrency("$amount","$standardCurrency");
    $chaosEquiv = "NULL" unless $chaosEquiv > 0;
    $dbh->do("INSERT IGNORE INTO \`thread-items\` SET uuid=\"$uuid\",
              threadid=\"$threadid\",
              md5sum=\"$md5sum\",
              amount=\"$amount\",
              added=\"$timestamp\",
              updated=\"$timestamp\",
              modified=\"$timestamp\",
              priceChanges=\"0\",
              verified=\"$data->[$activeFragment]->[1]{verified}\",
              chaosEquiv=$chaosEquiv,
              currency=\"$standardCurrency\",
              inES=\"no\"
              ") || die "SQL ERROR: $DBI::errstr\n";

  }

  # NOTE: this is after the thread stuff because thread updates might happen
  # but item stats are always the same or they're a new md5sum

  # Store MD5sum in database for analysis
  my $sqltightchunk = $dbh->quote($tightchunk);
  $dbh->do("INSERT IGNORE INTO `raw` SET `md5sum`=\"$md5sum\",
                `data`=$sqltightchunk") || die "SQL ERROR: $DBI::errstr\n";
  return;
}
