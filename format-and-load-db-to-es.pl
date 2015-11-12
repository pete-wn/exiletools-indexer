#!/usr/bin/perl

use Search::Elasticsearch;
use DBI;
use JSON;
use JSON::XS;
use Encode;
use Data::Dumper;
use Time::HiRes;
use Parallel::ForkManager;
require("subs/all.subroutines.pl");

# TO DO STUFF:
#
# identify unidentified uniques?

# == Initial Options 
# Whether or not to give basic debug output
$debug = 1;

# Whether or not to give SUPER VERBOSE output. USE WITH CARE! Will create huge logs
# and tons of spammy text.
$sv = 0;

# The number of processes to fork
$forkMe = 4;

# == Initial Startup
&StartProcess;

$dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}") || die "DBI Connection Error: $DBI::errstr\n";

# Access the database to build a lookup table of threadid information so that we don't waste
# time pulling this on an item-by-item basis.

&d("Building Thread/Account Lookup Table...\n");
my %sellerHash = %{$dbh->selectall_hashref("select `threadid`,`sellerAccount`,`sellerIGN`,`generatedWith`,`threadTitle` FROM `thread-last-update`","threadid")};


# The base query feeding this process will vary depending on the arguments given on the
# command line. Valid arguments currently include:
#   full - does a full update of everything
#   ###### - where ##### is an epoch timestamp, pulls all items newer than this
if ($ARGV[0] eq "full") {
  &d("!! WARNING: FULL UPDATE SPECIFIED! All previously indexed items will be scanned and re-indexed.\n");
  print localtime()." Selecting items from items\n";
  $pquery = "select `uuid` from `items` where `inES`=\"yes\"";
  $cquery = "select count(`uuid`) from `items` where `inES`=\"yes\"";
} elsif ($ARGV[0]) {
  $pquery = "select `uuid` from `items` where `updated`>$ARGV[0]";
  $cquery = "select count(`uuid`) from `items` where `updated`>$ARGV[0]";
} else {
  $pquery = "select `uuid` from `items` where `inES`=\"no\"";
  $cquery = "select count(`uuid`) from `items` where `inES`=\"no\"";
}

# Get a count of how many items we will process
my $updateCount = $dbh->selectrow_array("$cquery");

if ($updateCount < 1) {
  &d("!! No new uuid's to process! Aborting run.\n");
  $dbh->disconnect;
  &ExitProcess;
}

# If this is a small update, override the number of forks to something that isn't wasteful
# (we shouldn't be processing less than 10k items per fork
my $maxForkCheck = int($updateCount / 10000 / $forkMe) + 1;

if ($maxForkCheck < $forkMe) {
  $forkMe = $maxForkCheck;
  &d(" > Overriding forks of threads to a max of $forkMe as update is small!\n");
}

# This is a little weird/clumsy. Basically, we are going to create a hash of uuid's for each
# fork to process, with the total number split across all the forks. So, to start with, we take
# the total number of items to be updated and divide them by the number of forks to see the max
# uuid's each fork should process.
$maxInHash = int($updateCount / $forkMe) + 1;

&d(" > $updateCount uuid's to be updated [$forkMe fork(s), $maxInHash per fork]\n");

$t0 = [Time::HiRes::gettimeofday];
&d("Preparing update hash:\n");
$query_handle=$dbh->prepare($pquery);
$query_handle->{"mysql_use_result"} = 1;
$query_handle->execute();
$query_handle->bind_columns(undef, \$uuid);

# Keeps track of our active fork ID's
$forkID = 1;
# For tracking our iterations through the query
my $ucount = 0;

# Basically, iterate through the select by uuid, and add all uuid's to a hash table for
# the forkID until the count exceeds maxInHash, then increment the forkID
while($query_handle->fetch()) {
  $ucount++;
  if ($ucount > $maxInHash) {
    $forkID++;
    $ucount = 0;
  }
  $uhash{"$forkID"}{"$uuid"} = 1;
}

$dbh->disconnect;
$endelapsed = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
&d(" > Update hash built in $endelapsed seconds.\n");

# Prepare forkmanager
my $manager = new Parallel::ForkManager( $forkMe );
&d("Processing started! This may take awhile...\n");

# For each forkID in our hash of UUID's, fork a process and go!
foreach $forkID (keys(%uhash)) {

  $manager->start and next;
  $dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}") || die "DBI Connection Error: $DBI::errstr\n";

  my $e = Search::Elasticsearch->new(
    cxn_pool => 'Sniff',
    nodes =>  [
      "$conf{eshost}:9200",
      "$conf{eshost2}:9200"
    ],
    trace_to => ['File','/tmp/eslog.txt'],
    # Huge request timeout for bulk indexing
    request_timeout => 300
  );

  die "some error?"  unless ($e);
  
  my $bulk = $e->bulk_helper(
    index => "$conf{esindex}",
    max_count => '5100',
    max_size => '0',
    type => "$conf{estype}",
  );

  $t0 = [Time::HiRes::gettimeofday];

  foreach $uuid (keys(%{$uhash{$forkID}})) {
    my @datarow = $dbh->selectrow_array("select * from `items` where `uuid`=\"$uuid\" limit 1");
    my $uuid = $datarow[0];
    my $threadid = $datarow[1];
    my $md5sum = $datarow[2];
    my $added = $datarow[3];
    my $updated = $datarow[4];
    my $modified = $datarow[5];
    my $currency = $datarow[6];
    my $amount = $datarow[7];
    my $verified = $datarow[8];
    my $priceChanges = $datarow[9];
    my $lastUpdateDB = $datarow[10];
    my $chaosEquiv = $datarow[11];
    my $inES = $datarow[12];

    $count++;
    no autovivification;
    local %item;

    if ($sellerHash{$threadid}{threadTitle}) {
      $item{shop}{threadTitle} = $sellerHash{$threadid}{threadTitle};
    } else {
      my $threadTitle = $dbh->selectrow_array("select `title` from `web-post-track` where `threadid`=\"$threadid\"");
      if ($threadTitle) {
        $item{shop}{threadTitle} = $threadTitle;
      } else {
        $item{shop}{threadTitle} = "Unknown";
      } 
    }

    $item{uuid} = $uuid;
    $item{md5sum} = $md5sum;
    $item{shop}{threadid} = "$threadid";
    $item{shop}{added} += $added * 1000;
    $item{shop}{updated} += $updated * 1000;
    $item{shop}{modified} += $modified * 1000;
    $item{shop}{currency} = $currency;
    $item{shop}{amount} += $amount;
    $item{shop}{verified} = $verified;
    $item{shop}{priceChanges} += $priceChanges;
    $item{shop}{lastUpdateDB} = $lastUpdateDB;
    $item{shop}{chaosEquiv} += $chaosEquiv;
    $item{shop}{sellerAccount} = $sellerHash{$threadid}{sellerAccount};
    $item{shop}{sellerIGN} = $sellerHash{$threadid}{sellerIGN};
    $item{shop}{forumID} = $sellerHash{$threadid}{forumID};
    $item{shop}{generatedWith} = $sellerHash{$threadid}{generatedWith};

    my $rawjson = $dbh->selectrow_array("select `data` from `raw-json` where `md5sum`=\"$md5sum\" limit 1");
    unless ($rawjson) {
      print "[$forkID] WARNING: $md5sum returned no data from raw json db!\n";
      next;
    }
    local $data = decode_json(encode("utf8", $rawjson)) || print "$rawjson\n";
  
  # Let's not add originalJSON anymore
  #  $item{originalJSON} = "$rawjson";
  
    $item{info}{fullName} = $data->{name}." ".$data->{typeLine}; 
    $item{info}{fullName} =~ s/^Superior//g;
    $item{info}{fullName} =~ s/^\s+//g;
    $item{info}{fullName} =~ s/Maelst(.*?)m/Maelstrom/g;
    $item{info}{fullName} =~ s/Mj(.*?)lner/Mjolner/g;
    $item{info}{fullName} =~ s/Ngamahu(.*?)s Sign/Ngamahu\'s Sign/g;
    $item{info}{fullName} =~ s/Tasalio(.*?)s Sign/Tasalio\'s Sign/g;
    $item{info}{fullNameTokenized} = $item{info}{fullName};
  
  
    $item{info}{name} = $data->{name};
    $item{info}{name} =~ s/Maelst(.*?)m/Maelstrom/g;
    $item{info}{name} =~ s/Mj(.*?)lner/Mjolner/g;
    $item{info}{name} =~ s/Ngamahu(.*?)s Sign/Ngamahu\'s Sign/g;
    $item{info}{name} =~ s/Tasalio(.*?)s Sign/Tasalio\'s Sign/g;
  
    $item{info}{name} = $item{info}{fullName} unless ($item{info}{name});
    $item{info}{typeLine} = $data->{typeLine};
    $item{info}{descrText} = $data->{descrText};
    $item{info}{flavourText} = $data->{flavourText};
    $data->{icon} =~ /(.*?)\?/;
    $item{info}{icon} = $1;
    $item{attributes}{corrupted} = $data->{corrupted};
    $item{attributes}{support} = $data->{support};
    $item{attributes}{identified} = $data->{identified};
    $item{attributes}{frameType} = $data->{frameType};
    if ($data->{duplicated}) {
      $item{attributes}{mirrored} = $data->{duplicated};
    } else {
      $item{attributes}{mirrored} = \0;
    }
    if ($data->{lockedToCharacter}) {
      $item{attributes}{lockedToCharacter} = $data->{lockedToCharacter};
    } else {
      $item{attributes}{lockedToCharacter} = \0;
    }
    $item{attributes}{inventoryWidth} = $data->{w};
    $item{attributes}{inventoryHeight} = $data->{h};
    if ($data->{frameType} == 0) {
      $item{attributes}{rarity} = "Normal";
    } elsif ($data->{frameType} == 1) {
      $item{attributes}{rarity} = "Magic";
    } elsif ($data->{frameType} == 2) {
      $item{attributes}{rarity} = "Rare";
    } elsif ($data->{frameType} == 3) {
      $item{attributes}{rarity} = "Unique";
    } elsif ($data->{frameType} == 4) {
      $item{attributes}{rarity} = "Gem";
    } elsif ($data->{frameType} == 5) {
      $item{attributes}{rarity} = "Currency";
    } elsif ($data->{frameType} == 6) {
      $item{attributes}{rarity} = "Quest Item";
    }
  
  
  
    $item{attributes}{league} = $data->{league};
    local ($localItemType, $localBaseItemType) = &IdentifyType("");
    $item{attributes}{baseItemType} = $localBaseItemType;
    $item{attributes}{itemType} = $localItemType;
  
    # Determine Item Requirements & Properties
    my $explicitmodcount;
    my $craftedmodcount;
    my $implicitmodcount;
    my $cosmeticmodcount;
    for (my $p=0;$p <= 50;$p++) {
      if ($data->{requirements}[$p]{name}) {
        my $requirement = $data->{requirements}[$p]{name};
        $requirement = "Int" if ($requirement eq "Intelligence");
        $requirement = "Str" if ($requirement eq "Strength");
        $requirement = "Dex" if ($requirement eq "Dexterity");
        $requirement = ucfirst($requirement);
  
        my $value = $data->{requirements}[$p]{values}[0][0];
        $item{requirements}{$requirement} += $value;
      }
      if ($data->{properties}[$p]{name}) {
        my $property = $data->{properties}[$p]{name};
        my $value = $data->{properties}[$p]{values}[0][0];
        $value =~ s/\%//g;
        $value = \1 unless ($value);
  
        $property =~ s/\%0/#/g;
        $property =~ s/\%1/#/g;
  
        if ($data->{properties}[$p]{name} =~ /One Handed/) {
          $item{attributes}{equipType} = "One Handed Melee Weapon";
        } elsif ($data->{properties}[$p]{name} =~ /Two Handed/) {
          $item{attributes}{equipType} = "Two Handed Melee Weapon";
        }
  
        if ($data->{properties}[$p]{name} eq "Quality") {
          $value =~ s/\+//g;
        }
        if ($data->{properties}[$p]{name} =~ /^(.*?) \%0 (.*?) \%1 (.*?)$/) {
          $item{properties}{$item{attributes}{baseItemType}}{$property}{x} += $data->{properties}[$p]{values}[0][0];
          $item{properties}{$item{attributes}{baseItemType}}{$property}{y} += $data->{properties}[$p]{values}[1][0];
        } elsif ($value =~ /(\d+)-(\d+)/) {
          $item{properties}{$item{attributes}{baseItemType}}{$property}{min} += $1;
          $item{properties}{$item{attributes}{baseItemType}}{$property}{max} += $2;
        } else {
          if ($property =~ /\,/) {
            my @props = split(/\,/, $property);
            foreach $prop (@props) {
              $prop =~ s/^\s+//g;
              $item{properties}{$item{attributes}{baseItemType}}{type}{$prop} = \1;
            }
          } else {
            $item{properties}{$item{attributes}{baseItemType}}{$property} += $value;
          }
        }
      } elsif ($data->{properties}[$p]{values}[0][0]) {
        my $property = $data->{properties}[$p]{values}[0][0];
        my $value = $data->{properties}[$p]{values}[0][1];
        $item{properties}{$item{attributes}{baseItemType}}{$property} += $value;
      }
  
      if ($data->{explicitMods}[$p] =~ /^(\+|\-)?(\d+(\.\d+)?)(\%?)\s+(.*)$/) {
        my $modname = $5;
        my $value = $2;
        $modname =~ s/\s+$//g;
        $item{mods}{$item{attributes}{itemType}}{explicit}{"$1#$4 $modname"} += $value;
        $item{modsTotal}{"$1#$4 $modname"} += $value;
        $explicitmodcount++;
        &setPseudoMods("$1","$modname","$value");
  
      } elsif ($data->{explicitMods}[$p] =~ /^(.*?) (\+?\d+(\.\d+)?(-\d+(\.\d+)?)?%?)\s?(.*)$/) {
        my $modname;
        my $value = $2;
        my $prefix = $1;
        my $suffix = $6;
        if ($value =~ /\%/) {
          $modname = "$prefix #% $suffix";
          $value =~ s/\%//g;
        } elsif ($value =~ /\d+-\d+/) {
          $modname = "$prefix #-# $suffix";
        } else {
          $modname = "$prefix # $suffix";
        }
        $modname =~ s/\s+$//g;
        if ($data->{explicitMods}[$p] =~ /Unique Boss deals +(.*?)\% Damage and attacks +(.*?)% faster/) {
          $value = "$1-$2";
          $modname = "Unique Boss deals %# Damage and attacks %# faster";
        }
        if ($value =~ /(\d+)-(\d+)/) {
          $item{mods}{$item{attributes}{itemType}}{explicit}{$modname}{min} += $1;
          $item{mods}{$item{attributes}{itemType}}{explicit}{$modname}{max} += $2;
          
          $item{modsTotal}{$modname}{min} += $1;
          $item{modsTotal}{$modname}{max} += $2;
  
        } else {
          $item{mods}{$item{attributes}{itemType}}{explicit}{$modname} += $value;
          $item{modsTotal}{$modname} += $value;
        }
        $explicitmodcount++;
      } elsif ($data->{explicitMods}[$p]) {
        $item{mods}{$item{attributes}{itemType}}{explicit}{$data->{explicitMods}[$p]} = \1;
        $item{modsTotal}{$data->{explicitMods}[$p]} = \1;
        $explicitmodcount++;
      }
  
      if ($data->{craftedMods}[$p] =~ /^(\+|\-)?(\d+(\.\d+)?)(\%?)\s+(.*)$/) {
        my $modname = $5;
        my $value = $2;
        $modname =~ s/\s+$//g;
        $item{mods}{$item{attributes}{itemType}}{crafted}{"$1#$4 $modname"} += $value;
        $item{modsTotal}{"$1#$4 $modname"} += $value;
        $craftedmodcount++;
        &setPseudoMods("$1","$modname","$value");
      } elsif ($data->{craftedMods}[$p] =~ /^(.*?) (\+?\d+(\.\d+)?(-\d+(\.\d+)?)?%?)\s?(.*)$/) {
        my $modname;
        my $value = $2;
        my $prefix = $1;
        my $suffix = $6;
        if ($value =~ /\%/) {
          $modname = "$prefix #% $suffix";
          $value =~ s/\%//g;
        } elsif ($value =~ /\d+-\d+/) {
          $modname = "$prefix #-# $suffix";
        } else {
          $modname = "$prefix # $suffix";
        }
        $modname =~ s/\s+$//g;
        if ($value =~ /(\d+)-(\d+)/) {
          $item{mods}{$item{attributes}{itemType}}{crafted}{$modname}{min} += $1;
          $item{mods}{$item{attributes}{itemType}}{crafted}{$modname}{max} += $2;
          $item{modsTotal}{$modname}{min} += $1;
          $item{modsTotal}{$modname}{max} += $2;
        } else {
          $item{mods}{$item{attributes}{itemType}}{crafted}{$modname} += $value;
          $item{modsTotal}{$modname} += $value;
        }
        $craftedmodcount++;
      } elsif ($data->{craftedMods}[$p]) {
        $item{mods}{$item{attributes}{itemType}}{crafted}{$data->{craftedMods}[$p]} = \1;
        $item{modsTotal}{$item{attributes}{itemType}}{crafted}{$data->{craftedMods}[$p]} = \1;
        $craftedmodcount++;
      }
  
      if ($data->{implicitMods}[$p] =~ /^(\+|\-)?(\d+(\.?\d+)?)(\%?)\s+(.*)$/) {
        my $modname = $5;
        my $value = $2;
        $modname =~ s/\s+$//g;
        $item{mods}{$item{attributes}{itemType}}{implicit}{"$1#$4 $modname"} += $value;
        $item{modsTotal}{"$1#$4 $modname"} += $value;
        $implicitmodcount++;
        &setPseudoMods("$1","$modname","$value");
      } elsif ($data->{implicitMods}[$p] =~ /^(.*?) (\+?\d+(\.\d+)?(-\d+(\.\d+)?)?%?)\s?(.*)$/) {
        my $modname;
        my $value = $2;
        my $prefix = $1;
        my $suffix = $6;
        if ($value =~ /\%/) {
          $modname = "$prefix #% $suffix";
          $value =~ s/\%//g;
        } elsif ($value =~ /\d+-\d+/) {
          $modname = "$prefix #-# $suffix";
        } else {
          $modname = "$prefix # $suffix";
        }
        $modname =~ s/\s+$//g;
        if ($value =~ /(\d+)-(\d+)/) {
          $item{mods}{$item{attributes}{itemType}}{implicit}{$modname}{min} += $1;
          $item{mods}{$item{attributes}{itemType}}{implicit}{$modname}{max} += $2;
          $item{modsTotal}{$modname}{min} += $1;
          $item{modsTotal}{$modname}{max} += $2;
        } else {
          $item{mods}{$item{attributes}{itemType}}{implicit}{$modname} += $value;
          $item{modsTotal}{$modname} += $value;
        }
        $implicitmodcount++;
      } elsif ($data->{implicitMods}[$p]) {
        $item{mods}{$item{attributes}{itemType}}{implicit}{$data->{implicitMods}[$p]} = \1;
        $item{modsTotal}{$data->{implicitMods}[$p]} = \1;
        $implicitmodcount++;
      }
  
      if ($data->{cosmeticMods}[$p] =~ /^(\+|\-)?(\d+(\.?\d+)?)(\%?)\s+(.*)$/) {
        my $modname = $5;
        my $value = $2;
        $modname =~ s/\s+$//g;
        $item{mods}{$item{attributes}{itemType}}{cosmetic}{"$1#$4 $modname"} += $value;
        $item{modsCosmetic}{"$1#$4 $modname"} += $value;
        $cosmeticmodcount++;
      } elsif ($data->{cosmeticMods}[$p] =~ /^(.*?) (\+?\d+(\.\d+)?(-\d+(\.\d+)?)?%?)\s?(.*)$/) {
        my $modname;
        my $value = $2;
        my $prefix = $1;
        my $suffix = $6;
        if ($value =~ /\%/) {
          $modname = "$prefix #% $suffix";
          $value =~ s/\%//g;
        } elsif ($value =~ /\d+-\d+/) {
          $modname = "$prefix #-# $suffix";
        } else {
          $modname = "$prefix # $suffix";
        }
        $modname =~ s/\s+$//g;
        if ($value =~ /(\d+)-(\d+)/) {
          $item{mods}{$item{attributes}{itemType}}{cosmetic}{$modname}{min} += $1;
          $item{mods}{$item{attributes}{itemType}}{cosmetic}{$modname}{max} += $2;
          $item{modsCosmetic}{$modname}{min} += $1;
          $item{modsCosmetic}{$modname}{max} += $2;
        } else {
          $item{mods}{$item{attributes}{itemType}}{cosmetic}{$modname} += $value;
          $item{modsCosmetic}{$modname} += $value;
        }
        $cosmeticmodcount++;
      } elsif ($data->{cosmeticMods}[$p]) {
        $item{mods}{$item{attributes}{itemType}}{cosmetic}{$data->{cosmeticMods}[$p]} = \1;
        $item{modsCosmetic}{$data->{cosmeticMods}[$p]} = \1;
        $cosmeticmodcount++;
      }
    }

    $explicitmodcount = 0 unless ($explicitmodcount);
    $craftedmodcount = 0 unless ($craftedmodcount);
    $implicitmodcount = 0 unless ($implicitmodcount);
    $cosmeticmodcount = 0 unless ($cosmeticmodcount);
    $item{attributes}{explicitModCount} = $explicitmodcount;
    $item{attributes}{craftedModCount} = $craftedmodcount;
    $item{attributes}{implicitModCount} = $implicitmodcount;
    $item{attributes}{cosmeticModCount} = $cosmeticmodcount;
  
    # Calculate DPS
    if (($item{properties}{$item{attributes}{baseItemType}}{"Physical Damage"}{min} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Physical Damage"}{max} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"} > 0)) {
      $item{properties}{$item{attributes}{baseItemType}}{"Physical DPS"} += int(($item{properties}{$item{attributes}{baseItemType}}{"Physical Damage"}{min} + $item{properties}{$item{attributes}{baseItemType}}{"Physical Damage"}{max}) / 2 * $item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"});
    }
    if (($item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{min} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{max} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"} > 0)) {
      $item{properties}{$item{attributes}{baseItemType}}{"Elemental DPS"} += int(($item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{min} + $item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{max}) / 2 * $item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"});
    }
    if (($item{properties}{$item{attributes}{baseItemType}}{"Chaos Damage"}{min} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Chaos Damage"}{max} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"} > 0)) {
      $item{properties}{$item{attributes}{baseItemType}}{"Chaos DPS"} += int(($item{properties}{$item{attributes}{baseItemType}}{"Chaos Damage"}{min} + $item{properties}{$item{attributes}{baseItemType}}{"Chaos Damage"}{max}) / 2 * $item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"});
    }
    if ($item{properties}{$item{attributes}{baseItemType}}{"Physical DPS"} || $item{properties}{$item{attributes}{baseItemType}}{"Elemental DPS"} || $item{properties}{$item{attributes}{baseItemType}}{"Chaos DPS"}) {
      $item{properties}{$item{attributes}{baseItemType}}{"Total DPS"} += $item{properties}{$item{attributes}{baseItemType}}{"Physical DPS"} + $item{properties}{$item{attributes}{baseItemType}}{"Elemental DPS"} + $item{properties}{$item{attributes}{baseItemType}}{"Chaos DPS"};
    }
  
    #  if ($item{properties}{Armour}{Quality}) {
    #    if ($item{properties}{Armour}{"Energy Shield"}) {
    #      $item{propertiesQ20}{Armour}{"Energy Shield"} = $item{properties}{Armour}{"Energy Shield"} * (1.2 - ($item{properties}{Armour}{Quality} / 100));
    #    }
    #    if ($item{properties}{Armour}{"Armour"}) {
    #      $item{propertiesQ20}{Armour}{"Armour"} = $item{properties}{Armour}{"Armour"} * (1.2 - ($item{properties}{Armour}{Quality} / 100));
    #    }
    #    if ($item{properties}{Armour}{"Evasion"}) {
    #      $item{propertiesQ20}{Armour}{"Evasion"} = $item{properties}{Armour}{"Evasion"} * (1.2 - ($item{properties}{Armour}{Quality} / 100));
    #    }
    #  } elsif ($item{properties}{Weapon}{Quality}) {
    #    # Calculate Weapon Q20
    #  }
  
  
  
    # Set the equipType for weapons and stuff
    unless ($item{attributes}{equipType}) {
      if ($item{attributes}{baseItemType} eq "Weapon") {
        if ($item{attributes}{itemType} =~ /^(Claw|Dagger)$/) {
          $item{attributes}{equipType} = "One Handed Melee Weapon";
        } elsif ($item{attributes}{itemType} =~ /^(Wand)$/) {
          $item{attributes}{equipType} = "One Handed Projectile Weapon";
        } elsif ($item{attributes}{itemType} =~ /^(Staff)$/) {
          $item{attributes}{equipType} = "Two Handed Melee Weapon";
        } elsif ($item{attributes}{itemType} =~ /^(Bow)$/) {
          $item{attributes}{equipType} = "Bow";
        }
      } else {
        $item{attributes}{equipType} = $item{attributes}{itemType};
      } 
    }
    
    if ($data->{sockets}[0]{attr}) {
      my %sortGroup;
      ($item{sockets}{largestLinkGroup}, $item{sockets}{socketCount}, $item{sockets}{allSockets}, $item{sockets}{allSocketsSorted}, %sortGroup) = &ItemSockets();
      foreach $sortGroup (keys(%sortGroup)) {
        $item{sockets}{sortedLinkGroup}{$sortGroup} = $sortGroup{$sortGroup};
      }
    }
  
    # Add a PseudoMod for total resists
    foreach $elekey (keys (%{$item{modsPseudo}})) {
      $item{modsPseudo}{eleResistNum}++ if ($elekey =~ /^eleResistSum/);
    }
  
  
  # Clean Version Output
  #  my $jsonout = encode_json \%item;
  
    my $jsonout = JSON::XS->new->utf8->encode(\%item);
 
  # Some debugging stuff 
  # Pretty Version Output
  #  my $jsonchunk = JSON->new->utf8;
  #  my $prettychunk = $jsonchunk->pretty->encode(\%item);
  #  print "$prettychunk\n";
  #  exit if ($count > 2500);
  
    $bulk->index({ id => "$uuid", source => "$jsonout" });
    push @changeFlagInDB, "$uuid";
 
    # We go ahead and bulk flush then update the DB at 5000 manually so we can give some output
    # for anyone watching 
    if ($count % 5000 == 0) {
      &sv("[$forkID] [$count] Bulk Flushing Data to Elastic Search:\n");
      $bulk->flush;
      &sv("[$forkID] [$count] -> Bulk Flush Completed\n");
      &sv("[$forkID] [$count]  Marking items as imported in DB:\n");
      foreach $updateuuid (@changeFlagInDB) {
        $dbh->do("UPDATE \`items\` SET inES=\"yes\" WHERE uuid=\"$updateuuid\"");
      }
      &sv("[$forkID] [$count] -> Database update completed...\n");
      $endelapsed = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
      &d("[$forkID] [$count] Bulk Processed in $endelapsed seconds\n");
      $t0 = [Time::HiRes::gettimeofday];
      undef @changeFlagInDB;
    }
  
  }

  # Flush the leftover items - I'm lazy and just copy/pasted, should probably make this a subroutine 
  &sv("[$forkID] [$count] Bulk Flushing Data to Elastic Search:\n"); 
  $bulk->flush;
  &sv("[$forkID] [$count] -> Bulk Flush Completed\n");
  &sv("[$forkID] [$count]  Marking items as imported in DB:\n");
  foreach $updateuuid (@changeFlagInDB) {
    $dbh->do("UPDATE \`items\` SET inES=\"yes\" WHERE uuid=\"$updateuuid\"");
  }
  &sv("[$forkID] [$count] -> Database update completed...\n");
  $endelapsed = Time::HiRes::tv_interval ( $t0, [Time::HiRes::gettimeofday]);
  &d("[$forkID] [$count] Bulk Processed in $endelapsed seconds\n");
  undef @changeFlagInDB;
  
  &d("[$forkID] Elastic Search import complete!\n");
  
  $dbh->disconnect;
  $manager->finish;
}
$manager->wait_all_children;
&d("All processing children have completed their work!\n");

# == Exit cleanly
&ExitProcess;


sub IdentifyType {
  my $localBaseItemType;
  if ($data->{frameType} == 4) {
    $localBaseItemType = "Gem";
  } elsif ($data->{frameType} == 6) {
    if ($data->{icon} =~ /Divination\/InventoryIcon.png/) {
      $localBaseItemType = "Card";
    } else {
      $localBaseItemType = "Quest Item";
    }
  } elsif ($data->{frameType} == 5) {
    $localBaseItemType = "Currency";
  } elsif ($data->{descrText} =~ /Travel to this Map by using it in the Eternal Laboratory/) {
    $localBaseItemType = "Map";
  } elsif ($data->{descrText} =~ /Place into an allocated Jewel Socket/) {
    $localBaseItemType = "Jewel";
  } elsif ($data->{descrText} =~ /Right click to drink/) {
    $localBaseItemType = "Flask";
  } elsif ($gearBaseType{"$data->{typeLine}"}) {
    $localBaseItemType = $gearBaseType{"$data->{typeLine}"};
  } else {
    foreach my $gearbase (keys(%gearBaseType)) {
      if ($data->{typeLine} =~ /$gearbase/) {
        $localBaseItemType = $gearBaseType{"$gearbase"};
        last;
      }
    }
  }
  $localBaseItemType = "Unknown" unless ($localBaseItemType);

  my $localItemType;
  if ($localBaseItemType =~ /^(Bow|Axe|Sword|Dagger|Mace|Staff|Claw|Sceptre|Wand|Fishing Rod)$/) {
    $localItemType = "Weapon";
  } elsif ($localBaseItemType =~ /^(Helmet|Gloves|Boots|Body|Shield|Quiver)$/) {
    $localItemType = "Armour";
  } elsif ($localBaseItemType =~ /^(Amulet|Belt|Ring)$/) {
    $localItemType = "Jewelry";
  } else {
    $localItemType = $localBaseItemType;
  }
  return($localBaseItemType, $localItemType);
}

sub ItemSockets {
  my %sockets;
  my %sortGroup;

  for (my $socketprop=0;$socketprop <= 10;$socketprop++) {
    my $group = $data->{sockets}[$socketprop]{group};
    $sockets{group}{$group} .= $data->{sockets}[$socketprop]{attr} if ($data->{sockets}[$socketprop]{attr})
  }

  my $socketcount;
  my $allSockets;
  foreach my $group (sort keys(%{$sockets{group}})) {
#    print "[$threadid][$timestamp] $data->[$activeFragment]->[1]{name} Group: $group | Sockets: $sockets{group}{$group} (".length($sockets{group}{$group}).")\n";
    $sockets{maxLinks} = length($sockets{group}{$group}) if (length($sockets{group}{$group}) > $sockets{maxLinks});
    $sockets{count} = $sockets{count} + length($sockets{group}{$group});
  }


  foreach my $group (sort keys(%{$sockets{group}})) {
    $sockets{group}{$group} =~ s/G/W/g;
    $sockets{group}{$group} =~ s/D/G/g;
    $sockets{group}{$group} =~ s/S/R/g;
    $sockets{group}{$group} =~ s/I/B/g;
    $allSockets .= "-$sockets{group}{$group}";
    my @sort = sort (split(//, $sockets{group}{$group}));
    my $sorted = join("", @sort);
    $sortGroup{$group} = "$sorted";
  }
  $allSockets =~ s/^\-//g;

  my @sort = sort (split(//, $allSockets));
  my $sorted = join("", @sort);
  $sorted =~ s/\-//g;
  return($sockets{maxLinks},$sockets{count},$allSockets,$sorted,%sortGroup);


}

sub setPseudoMods {
  my $modifier = $_[0];
  my $modname = $_[1];
  my $value = $_[2];

  if ($modname =~ /to (\S+) Resistance/) {
    if ($modifier eq '+') {
      $item{modsPseudo}{eleResistTotal} += $value;
      $item{modsPseudo}{"eleResistSum$1"} += $value;
    } else {
      $item{modsPseudo}{eleResistTotal} -= $value;
      $item{modsPseudo}{"eleResistSum$1"} -= $value;
    }
  } elsif ($modname =~ /to (\S+) and (\S+) Resistances/) {
    if ($modifier eq '+') {
      $item{modsPseudo}{eleResistTotal} += $value;
      $item{modsPseudo}{eleResistTotal} += $value;
      $item{modsPseudo}{"eleResistSum$1"} += $value;
      $item{modsPseudo}{"eleResistSum$2"} += $value;
    } else {
      $item{modsPseudo}{eleResistTotal} -= $value;
      $item{modsPseudo}{eleResistTotal} -= $value;
      $item{modsPseudo}{"eleResistSum$1"} -= $value;
      $item{modsPseudo}{"eleResistSum$2"} -= $value;
    }
  } elsif ($modname =~ /to all Elemental Resistances/) {
    if ($modifier eq '+') {
      $item{modsPseudo}{eleResistTotal} += $value;
      $item{modsPseudo}{eleResistTotal} += $value;
      $item{modsPseudo}{eleResistTotal} += $value;
      $item{modsPseudo}{eleResistSumFire} += $value;
      $item{modsPseudo}{eleResistSumCold} += $value;
      $item{modsPseudo}{eleResistSumLightning} += $value;
    } else {
      $item{modsPseudo}{eleResistTotal} -= $value;
      $item{modsPseudo}{eleResistTotal} -= $value;
      $item{modsPseudo}{eleResistTotal} -= $value;
      $item{modsPseudo}{eleResistSumFire} -= $value;
      $item{modsPseudo}{eleResistSumCold} -= $value;
      $item{modsPseudo}{eleResistSumLightning} -= $value;
    }
  } elsif ($modname =~ /to Intelligence$/) {
    $item{modsPseudo}{flatAttributesTotal} += $value;
    $item{modsPseudo}{flatSumInt} += $value;
  } elsif ($modname =~ /to Dexterity$/) {
    $item{modsPseudo}{flatAttributesTotal} += $value;
    $item{modsPseudo}{flatSumDex} += $value;
  } elsif ($modname =~ /to Strength$/) {
    $item{modsPseudo}{flatAttributesTotal} += $value;
    $item{modsPseudo}{flatSumStr} += $value;
    $item{modsPseudo}{"maxLife"} += int($value / 2);
  } elsif ($modname =~ /to Strength and Intelligence$/) {
    $item{modsPseudo}{flatAttributesTotal} += $value;
    $item{modsPseudo}{flatAttributesTotal} += $value;
    $item{modsPseudo}{flatSumStr} += $value;
    $item{modsPseudo}{flatSumInt} += $value;
    $item{modsPseudo}{"maxLife"} += int($value / 2);
  } elsif ($modname =~ /to Dexterity and Intelligence$/) {
    $item{modsPseudo}{flatAttributesTotal} += $value;
    $item{modsPseudo}{flatAttributesTotal} += $value;
    $item{modsPseudo}{flatSumDex} += $value;
    $item{modsPseudo}{flatSumInt} += $value;
  } elsif ($modname =~ /to Strength and Dexterity/) {
    $item{modsPseudo}{flatAttributesTotal} += $value;
    $item{modsPseudo}{flatAttributesTotal} += $value;
    $item{modsPseudo}{flatSumStr} += $value;
    $item{modsPseudo}{flatSumDex} += $value;
    $item{modsPseudo}{"maxLife"} += int($value / 2);
  } elsif ($modname =~ /to all Attributes/) {
    $item{modsPseudo}{flatAttributesTotal} += $value;
    $item{modsPseudo}{flatAttributesTotal} += $value;
    $item{modsPseudo}{flatAttributesTotal} += $value;
    $item{modsPseudo}{flatSumStr} += $value;
    $item{modsPseudo}{flatSumDex} += $value;
    $item{modsPseudo}{flatSumInt} += $value;
    $item{modsPseudo}{"maxLife"} += int($value / 2);
  } elsif ($modname =~ /to maximum Life/) {
    $item{modsPseudo}{"maxLife"} += $value;
  }
}
