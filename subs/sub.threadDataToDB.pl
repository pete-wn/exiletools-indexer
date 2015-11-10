#!/usr/bin/perl

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

sub LoadUpdate {
  local $threadid = $_[0];
  local $timestamp = $_[1];
  local $conf{datadir} = "$conf{datadir}/$threadid";
  my $content;

  $dbhf->do("UPDATE `shop-queue` SET
                 processed=\"1\"
                 WHERE `threadid`=\"$threadid\" AND `timestamp`=\"$timestamp\"
                 ") || die "SQL ERROR: $DBI::errstr\n";


  # Need to clean this up too
  if (-f "$conf{datadir}/raw/$timestamp.html") {
    &d("  Found $conf{datadir}/raw/$timestamp.html\n");
    my $parseActive;
    open(IN, "$conf{datadir}/raw/$timestamp.html") || die "ERROR unable to open $conf{datadir}/raw/$timestamp.html - $!\n";
    while(<IN>) {
      my $line = $_;
      $content .= $line;
      chomp($line);

      if ($line =~ /require\(\[\"PoE\/Item\/DeferredItemRenderer\"\], function\(R\) \{ \(new R\((.*?)\)\)\.run\(\)\; \}\)\;/) {
        $rawjson = $1;
      }
    }
    close(IN);

    my ($status) = &ProcessUpdate("$content","$rawjson");

  } else {
    &d("WARNING: HTML data not found for $conf{datadir}/raw/$timestamp.html - possible ERROR. Skipping.\n");
    $dbhf->do("UPDATE `shop-queue` SET
                   processed=\"5\",
                   nojsonfound=\"1\"
                   WHERE `threadid`=\"$threadid\" AND `timestamp`=\"$timestamp\"
                   ") || die "SQL ERROR: $DBI::errstr\n";
    return;
  }
}

sub ProcessUpdate {
  my $content = $_[0];
  my $rawjson = $_[1];

  # Prepare some hashes to make sure they don't leak globally
  local %fragments;
  local %threadInfo;

  my $fulltree = HTML::Tree->new();
  $fulltree->parse($content);

  # Find the thread title by looking for the h1 class=layoutBoxTitle
  my $threadTitle = $fulltree->look_down('_tag' => 'h1', 'class' => 'topBar last layoutBoxTitle');
  $threadInfo{threadTitle} = $threadTitle->as_text;

  # Load the first content container TD, which should be the entire first post
  $tree = $fulltree->look_down('_tag' => 'td', 'class' => 'content-container first');

  # Everything from here down will be looking at the first post unless it references fulltree

  # Look for IGN in the container text via regexp:
  #  IGN followed by an optional : followed by one or more spaces
  #  followed by an option "is" with spaces around it
  #  followed by a word
  #  followed by a period or a closing tag or spaces
  if ($tree->as_text =~ /IGN:?\s*(?:is\s*)(\S+?)(<|\.)\s*/) {
    $threadInfo{sellerIGN} = $1;
  }

  # Look for a global buyout
  if ($tree->as_text =~ /\~gb\/o\s*((?:\d+)*(?:(?:\.|,)\d+)?)\s*([A-Za-z]+)\s*<*.*$/) {
    local $globalAmount = $1;
    local $globalCurrency = $1;
  }

  # Look for a known Procurement image or Acquisition Plus text
  if ($tree->as_text  =~ /i\.imgur\.com\/ZHBMImo\.png/) {
    $threadInfo{generatedWith} = "Procurement";
  } elsif ($tree->as_text =~ /github.com\/Novynn\/acquisitionplus\/releases/) {
    $threadInfo{generatedWith} = "Acquisition Plus";
  }

  # From here, things get a bit sketchy. We can't simply parse the tree using HTML::Tree, because
  # we're looking for content that is outside tags in the way this is formatted.
  # For example (simplified), we need to look for:
  #
  # <div class="spoiler">
  # <div class="itemFragment"></div><br />~b/o 10 chaos<br />
  # <div class="itemFragment"></div><br />~b/o 10 chaos<br />
  # <div class="itemFragment"></div><br />~b/o 10 chaos<br />
  # </div>
  #
  # Because the text is part of the main spoiler div and isn't obviously tied to an itemfragment,
  # I've found it's easier to build regexp's out of this data.
  # 
  # This is very annoying, btw. To do this properly we should be able to enclose buyout tags
  # in the divs, i.e.
  #
  # <div class="item"><div class="itemFragment"></div>~b/0 10 chaos</div>
  #
  # alas.

  # First we look at content outside spoiler elements. This is a little ugly. 
  # I can't figure out how to specify a max depth when pulling elements, so
  # we're going to go ahead and get a string of the content back and forcibly remove
  # all spoilers from it before we start parsing for items
  my $inside = $tree->as_HTML;
  $inside =~ s/<div.*?spoiler.*?>.*?<\/div>//g;

  # Now inside is clean(ish), so we can split it and look for frags
  # The ParseContentForFrags subroutine basically reformats the string
  # into a bunch of lines split by item fragments and goes from there
  &ParseContentForFrags("$inside");


  foreach my $spoiler ($tree->look_down('_tag' => 'div', 'class' => 'spoiler spoilerHidden')) {
    # Find the spoilerTitle elements and bring them back as text to see if there's a buyout
    local $spoilerTitle = $spoiler->look_down('_tag' => 'div', 'class' => 'spoilerTitle');
    $spoilerTitle = $spoilerTitle->as_text;
    # Remove unnecessary characters
    $spoilerTitle =~ tr/\~\/a-zA-Z0-9\,\& //dc;
#    print "Spoiler Title: \"$spoilerTitle\"\n";

    # Look down for the spoilerContent div(s)
    foreach $spoilerContent ($spoiler->look_down('_tag' => 'div', 'class' => 'spoilerContent')) {
      # Reformat the data inside this spoiler to make it regexp safe, sigh
      my $inside = $spoilerContent->as_HTML;
      &ParseContentForFrags("$inside");
    }
  }

  # Look down to find the last_edited_by div if it exists
  my $editInfo = $tree->look_down('_tag' => 'div', 'class' => 'last_edited_by');
  if ($editInfo) {
    $threadInfo{LastEditedBy} = $editInfo->as_text;
    $threadInfo{LastEditedBy} =~ /^Last edited by (\S+) on (.*?)$/;
    $threadInfo{LastEditTime} = $2;
    $threadInfo{LastEditEpoch} = str2time($2);

    # Add the lastedit information to web-post-track
    $dbhf->do("UPDATE `web-post-track` SET
              `lastedit`=\"$threadInfo{LastEditEpoch}\"
              WHERE `threadid`=\"$threadid\"
              ") || die "FATAL DBI ERROR: $DBI::errstr\n";
  }

  # Look down to find the profile-link post_by_account span
  my $postInfo = $fulltree->look_down('_tag' => 'span', 'class' => qr/profile-link post_by_account/);
  $threadInfo{sellerAccount} = $postInfo->as_text;

  unless ($rawjson) {
    &d("  WARNING: JSON data not found in $conf{datadir}/raw/$timestamp.html - possible empty update. Skipping.\n");
    $dbhf->do("UPDATE `shop-queue` SET
                   processed=\"5\",
                   jsonfound=\"0\"
                   WHERE `threadid`=\"$threadid\" AND `timestamp`=\"$timestamp\"
                   ") || die "SQL ERROR: $DBI::errstr\n";
    return;
  }

  # Remove funky <<set formatting from raw json
  $rawjson =~ s/\<\<set:(\S+?)\>\>//g;

  # encode the JSON data into something perl can reference 
  local $data = decode_json(encode("utf8", $rawjson));
 
  # set some more local variables 
  # these are modified by parsing subroutines called from here
  local $itemsAdded;
  local $itemsIgnored;
  local $itemsRemoved;
  local $itemsModified;
  local $itemsUpdated;
  local $buyoutCount;
  local $totalItems;


  # Iterate through the ActiveFragment hash to call ProcessItemFragment which will
  # pull out the JSON data and add appropriate data to the database
  foreach $activeFragment(sort {$a <=> $b} (keys(%fragments))) {
    # Note: We just just reference all this data, but I'm sending it as subroutine options for simplicity
    &ProcessItemFragment("$activeFragment","$fragments{$activeFragment}{PriceType}","$fragments{$activeFragment}{PriceAmount}","$fragments{$activeFragment}{PriceCurrency}","$fragments{$activeFragment}{SpoilerTitle}","$threadid","$timestamp");
  }


  # Select all items in the database for this threadid that aren't already listed as GONE and are from before this update
  my $oldhash = $dbhf->selectall_hashref("SELECT * FROM `items` WHERE \`threadid\`=\"$threadid\" AND \`verified\`!=\"GONE\" AND \`updated\`<\"$timestamp\"","uuid") || die "ERROR: $DBI::errstr\n";
  # Since these are all items which either used to be in this thread and no longer are, or were skipped because they are no longer
  # verified, just iterate through them and mark them as GONE
  foreach my $uuid (keys(%{$oldhash})) {
    $dbhf->do("UPDATE \`items\` SET
              verified=\"GONE\",
              updated=\"$timestamp\",
              modified=\"$timestamp\",
              inES=\"no\"
              WHERE uuid=\"$uuid\"
              ") || die "SQL ERROR: $DBI::errstr\n";
    $itemsRemoved++;
  }
 
  # Add some statistics to the history table  
  $dbhf->do("INSERT IGNORE INTO \`thread-update-history\` SET
            threadid=\"$threadid\",
            updateTimestamp=\"$timestamp\",
            itemsAdded=\"$itemsAdded\",
            itemsRemoved=\"$itemsRemoved\",
            itemsModified=\"$itemsModified\",
            sellerAccount=\"$threadInfo{sellerAccount}\",
            sellerIGN=\"$threadInfo{sellerIGN}\",
            totalItems=\"$totalItems\",
            buyoutCount=\"$buyoutCount\",
            generatedWith=\"$threadInfo{generatedWith}\",
            threadTitle=\"$threadInfo{threadTitle}\"
            ") || die "SQL ERROR: $DBI::errstr\n";

  # We also keep a table with only information from the last update for quick searching.
  $dbhf->do("INSERT INTO \`thread-last-update\` VALUES
            (\"$threadid\",\"$timestamp\",\"$itemsAdded\",\"$itemsRemoved\",\"$itemsModified\",\"$threadInfo{sellerAccount}\",\"$threadInfo{sellerIGN}\",\"$totalItems\",\"$buyoutCount\",\"$threadInfo{generatedWith}\",\"$threadInfo{threadTitle}\")
            ON DUPLICATE KEY UPDATE
            threadid=\"$threadid\",
            updateTimestamp=\"$timestamp\",
            itemsAdded=\"$itemsAdded\",
            itemsRemoved=\"$itemsRemoved\",
            itemsModified=\"$itemsModified\",
            sellerAccount=\"$threadInfo{sellerAccount}\",
            sellerIGN=\"$threadInfo{sellerIGN}\",
            totalItems=\"$totalItems\",
            buyoutCount=\"$buyoutCount\",
            generatedWith=\"$threadInfo{generatedWith}\",
            threadTitle=\"$threadInfo{threadTitle}\"
            ") || die "SQL ERROR: $DBI::errstr\n";

  &d("  generatedWith: $threadInfo{generatedWith} | sellerAccount: $threadInfo{sellerAccount} | sellerIGN: $threadInfo{sellerIGN} | $itemsAdded Added | $itemsRemoved Removed | $itemsModified Modified | $itemsUpdated Updated | $buyoutCount Buyouts Detected | $itemsIgnored ignored\n");

  $dbhf->do("UPDATE `shop-queue` SET
                 processed=\"2\"
                 WHERE `threadid`=\"$threadid\" AND `timestamp`=\"$timestamp\"
                 ") || die "SQL ERROR: $DBI::errstr\n";

}

sub ProcessItemFragment {
  # Set some local variables based on the data input to the subroutine
  my $activeFragment = $_[0];
  my $type = $_[1];
  my $amount = $_[2];
  # Replace commas with periods because that's what most systems work with
  $amount =~ s/\,/\./g;
  my $currency = $_[3];
  my $spoilertag = "[spoilertag] " if ($_[4] eq "spoiler");
  my $threadid = $_[5];
  my $timestamp = $_[6];

  &sv(">> Processing Item Fragment $activeFragment\n");

  # Extract the item fragment JSON data so that we can md5sum it and save it
  my $fragmentJSON = encode_json ($data->[$activeFragment]->[1]);
  local $md5sum = md5_hex($fragmentJSON);

  # Skip if it's a quest item
# Disabled because of divination cards, dammit.
#  return if ($data->[$activeFragment]->[1]{frameType} == 6); 

  # If an item isn't verified, just skip it - we will detect it as removed from the
  # update and mark it "GONE" later
  unless ($data->[$activeFragment]->[1]{verified}) {
    &sv("$activeFragment is no longer verified, skipping.\n");
    return;
  }

  # Use the currencyName hash loaded in the sub.currencyNames.pl file to change
  # the stupid name in the HTML to a standardized currency name.
  # i.e. "exa" ($currency) to "Exalted Orb" ($standardCurrency)
  my $standardCurrency;
  if ($currencyName{$currency}) {
    $standardCurrency = $currencyName{$currency};  # We know what it is
  } elsif ($currency) {
    $standardCurrency = "Unknown ($currency)"; # We don't know what it is, why isn't this in the currency hash?
  } else{
    $amount = ""; # if there was an amount set, there's no currency, so nuke it
    $standardCurrency = "NONE"; # set currency to NONE because currency isn't set
  }

  my $uuid = "$threadid:$md5sum";  

  # Get any current information about this item from the database based on uuid
  my $threadshash = $dbhf->selectrow_hashref("SELECT added,updated,modified,currency,amount FROM \`items\` WHERE uuid=\"$uuid\" LIMIT 1");

  # Don't update a record if the information in the database exactly matches this run
  if ($threadshash->{"updated"} == $timestamp) {
    $itemsIgnored++;
    &sv(">>> Data in database matches current data, is this a duplicate? Ignoring.\n");
    return;
  }

  # Increment the number of totalItems for this iteration
  $totalItems++;

  # If the item was previously added, but the currency or amount has changed, it is considered MODIFIED
  if ($threadshash->{"added"} && (($threadshash->{"currency"} ne "$standardCurrency") || ($threadshash->{"amount"} != "$amount"))) {
    &sv("[$threadid][$timestamp][MODIFIED] $activeFragment ($name) ($uuid) Currency Was ".$threadshash->{"amount"}." ".$threadshash->{"currency"}." | IS NOW $amount $standardCurrency from $fragments{$activeFragment}{PriceSource}\n"); 
    $itemsModified++;
 
    my $chaosEquiv = &StandardizeCurrency("$amount","$standardCurrency");
    $chaosEquiv = "NULL" unless $chaosEquiv > 0;

    $dbhf->do("UPDATE \`items\` SET
              amount=\"$amount\",
              updated=\"$timestamp\",
              modified=\"$timestamp\",
              verified=\"$data->[$activeFragment]->[1]{verified}\",
              chaosEquiv=$chaosEquiv,
              currency=\"$standardCurrency\",
              inES=\"no\"
              WHERE uuid=\"$uuid\"
              ") || die "SQL ERROR: $DBI::errstr\n";

  # Otherwise if everything is the same, but the item had already been added, then this is just a simple update
  } elsif ($threadshash->{"added"}) {
    $itemsUpdated++;
    &sv("[$threadid][$timestamp][UPDATED] No change to $activeFragment ($uuid)\n");
    $dbhf->do("UPDATE \`items\` SET
              verified=\"$data->[$activeFragment]->[1]{verified}\",
              updated=\"$timestamp\",
              inES=\"no\"
              WHERE uuid=\"$uuid\"
              ") || die "SQL ERROR: $DBI::errstr\n";

  # Otherwise, the item is new and just added
  } else {
    &sv("[$threadid][$timestamp][ADDED] $activeFragment ($uuid) | $amount $standardCurrency from $fragments{$activeFragment}{PriceSource}\n");
    $itemsAdded++;
    my $chaosEquiv = &StandardizeCurrency("$amount","$standardCurrency");
    $chaosEquiv = "NULL" unless $chaosEquiv > 0;
    $dbhf->do("INSERT IGNORE INTO \`items\` SET uuid=\"$uuid\",
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

  # Store MD5sum in database for analysis - insert ignore is faster than selecting to see if
  # it exists and skipping if so.
  my $sqlfragmentJSON = $dbhf->quote($fragmentJSON);
  $dbhf->do("INSERT IGNORE INTO `raw-json` SET `md5sum`=\"$md5sum\",
                `data`=$sqlfragmentJSON") || die "SQL ERROR: $DBI::errstr\n";
  return;
}

sub ParseContentForFrags {
  my $inside = $_[0];
  my @inside = split(/<div class=\"itemFragment/, $inside);
  foreach $insideline (@inside) {
    if ($insideline =~ /id=\"item-fragment-(\d+)\"/) {
      my $activeFragment = $1;

      # Let's save some info for analysis later, just in case
      $fragments{$activeFragment}{OriginalLine} = '<div class="itemFragment"'.$insideline;
      $fragments{$activeFragment}{SpoilerTitle} = $spoilerTitle if ($spoilerTitle);

      # This is a bit of a complicated regexp. In short:
      #   look for ~b/o or ~price
      #   followed by zero or more spaces
      #   followed by a whole number or decimal, formatted like 3.5 or 3,5
      #   followed by zero or more spaces
      #   followed by a word (currency)
      #   followed optionally by spaces, a closing tag (i.e. <br), any other characters, and the end of the string

      if ($insideline =~ /\~(b\/o|price|c\/o)\s*((?:\d+)*(?:(?:\.|,)\d+)?)\s*([A-Za-z]+)\s*<*.*$/) {
        $fragments{$activeFragment}{PriceType} = $1;
        $fragments{$activeFragment}{PriceAmount} = $2;
        $fragments{$activeFragment}{PriceCurrency} = $3;
        $fragments{$activeFragment}{PriceSource} = "Under Item";
        $buyoutCount++;
      # also check the spoilerTitle of the current spoiler to see if it has price info
      } elsif ($spoilerTitle =~ /\~(b\/o|price|c\/o)\s*((?:\d+)*(?:(?:\.|,)\d+)?)\s*([A-Za-z]+)\s*<*.*$/) {
        $fragments{$activeFragment}{PriceType} = $1;
        $fragments{$activeFragment}{PriceAmount} = $2;
        $fragments{$activeFragment}{PriceCurrency} = $3;
        $fragments{$activeFragment}{PriceSource} = "Spoiler Title";
        $buyoutCount++;
      # and failing that, check for a global buyout
      } elsif ($globalAmount && $globalCurrency) {
        $fragments{$activeFragment}{PriceType} = "b/o";
        $fragments{$activeFragment}{PriceAmount} = $globalAmount;
        $fragments{$activeFragment}{PriceCurrency} = $globalCurrency;
        $fragments{$activeFragment}{PriceSource} = "Global Buyout";
        $buyoutCount++;
      } else {
        $fragments{$activeFragment}{PriceSource} = "Nowhere";
      }
    }
  }
}

return("true");
