#!/usr/bin/perl

require('subs/sub.uniqueItemInfoHash.pl');

sub formatJSON {

  # Derefence the incoming hash for ease of use
  local %data = %{ $_[0] };

  

  # Localize the item hash
  local %item;

  # New API data
  $item{shop}{sellerAccount} = $_[1];
  $item{shop}{stash}{stashID} = $_[2];
  $item{shop}{stash}{stashName} = $_[3];
  $item{shop}{lastCharacterName} = $_[4];

  $item{shop}{stash}{inventoryID} = $data{inventoryId};
  $item{shop}{stash}{xLocation} += $data{x};
  $item{shop}{stash}{yLocation} += $data{y};

  # How to calculate a UUID?
  $item{uuid} = "$item{shop}{stash}{stashID}-$item{shop}{stash}{xLocation}-$item{shop}{stash}{yLocation}";

  # Now that we have a UUID, lets find this item in currentStashData. We have to iterate
  # because the results are in array format
  # We also clear out any matching elements from the array, so at the end we are left with only items
  # that are no longer verified
  my $itemInES;
  my $scanCount = 0;
  foreach $scanItem (@{$currentStashData->{hits}->{hits}}) {
    if ($scanItem->{_source}->{uuid} eq $item{uuid}) {
      $itemInES = $scanItem->{_source};
      $currentStashData->{hits}->{hits}->[$scanCount] = undef;
      last;
    }
    $scanCount++;
  }


  $item{shop}{note} = $data{note} if ($data{note});
  # Process Price
  # If there is a price in the note, then set that
  # Otherwise, if there is a price in the stashName, then set that
  # Should probably put the price conversion stuff into a subroutine, oh well
  if ($item{shop}{note} =~ /\~(b\/o|price|c\/o)\s*((?:\d+)*(?:(?:\.|,)\d+)?)\s*([A-Za-z]+)\s*.*$/) {
    my $priceType = lc($1);
    my $priceAmount = $2;
    my $priceCurrency = lc($3);

    # Convert this to a fixed currency name
    my $standardCurrency;
    if ($currencyName{$priceCurrency}) {
      $standardCurrency = $currencyName{$priceCurrency};  # We know what it is
    } elsif ($priceCurrency) {
      $standardCurrency = "Unknown ($priceCurrency)"; # We don't know what it is, why isn't this in the currency hash?
    } else{
      $amount += 0; # if there was an amount set, there's no currency, so nuke it
#      $standardCurrency = "NONE"; # set currency to NONE because currency isn't set
    }

    $item{shop}{amount} += $priceAmount if ($priceAmount > 0);
    $item{shop}{currency} = $standardCurrency if ($standardCurrency);
    $item{shop}{price}{"$standardCurrency"} += $priceAmount if ($priceAmount > 0);
    $item{shop}{saleType} = $priceType;
    $item{shop}{priceSource} = "note";
    if ($item{shop}{amount} ) {
      $item{shop}{chaosEquiv} += &StandardizeCurrency("$priceAmount","$standardCurrency");
    }
  } elsif ($item{shop}{stash}{stashName} =~ /\~(b\/o|price|c\/o|gb\/o)\s*((?:\d+)*(?:(?:\.|,)\d+)?)\s*([A-Za-z]+)\s*.*$/) {
    my $priceType = lc($1);
    my $priceAmount = $2;
    my $priceCurrency = lc($3);
    
    # Convert this to a fixed currency name
    my $standardCurrency;
    if ($currencyName{$priceCurrency}) {
      $standardCurrency = $currencyName{$priceCurrency};  # We know what it is
    } elsif ($priceCurrency) {
      $standardCurrency = "Unknown ($priceCurrency)"; # We don't know what it is, why isn't this in the currency hash?
    } else{
      $amount += 0; # if there was an amount set, there's no currency, so nuke it
# Removed for https://github.com/trackpete/exiletools-indexer/issues/112
#      $standardCurrency = "NONE"; # set currency to NONE because currency isn't set
    }

    $item{shop}{amount} += $priceAmount if ($priceAmount > 0);
    $item{shop}{currency} = $standardCurrency if ($standardCurrency);
    $item{shop}{price}{"$standardCurrency"} += $priceAmount if ($priceAmount > 0);
    $item{shop}{saleType} = $priceType;
    $item{shop}{priceSource} = "stashName";
    if ($item{shop}{amount}) {
      $item{shop}{chaosEquiv} += &StandardizeCurrency("$priceAmount","$standardCurrency");
    }
  } else {
    $item{shop}{saleType} = "Offer";
# Do not set these values if there is no price
# https://github.com/trackpete/exiletools-indexer/issues/112
#    $item{shop}{priceSource} = null;
#    $item{shop}{currency} = null;
#    $item{shop}{amount} += 0;
#    $item{shop}{chaosEquiv} = 0;
  }




  $item{attributes}{league} = $data{league};
#  return("FAIL: Unknown League") if ($data{league} eq "Unknown");
  $item{attributes}{identified} = $data{identified};
  $item{info}{icon} = $data{icon};
  # Strip anything after a ? from it, no need to have forced dimensions
  $item{info}{icon} =~ s/\?.*$//g;

  # Remove the Superior and/or any leading white space from typeLine
  $data{typeLine} =~ s/^(Superior |\s+)//o;

  # If the item has talismanTier data over 1, add that
  $item{attributes}{talismanTier} = $data{talismanTier} if ($data{talismanTier} > 0);

  $item{attributes}{frameType} = $data{frameType};
  # Set the item rarity based on frameType digit
  if ($data{frameType} == 0) {
    $item{attributes}{rarity} = "Normal";
  } elsif ($data{frameType} == 1) {
    $item{attributes}{rarity} = "Magic";
  } elsif ($data{frameType} == 2) {
    $item{attributes}{rarity} = "Rare";
  } elsif ($data{frameType} == 3) {
    $item{attributes}{rarity} = "Unique";
  } elsif ($data{frameType} == 4) {
    $item{attributes}{rarity} = "Gem";
  } elsif ($data{frameType} == 5) {
    $item{attributes}{rarity} = "Currency";
  } elsif ($data{frameType} == 6) {
    $item{attributes}{rarity} = "Divination Card";
  } elsif ($data{frameType} == 7) {
    $item{attributes}{rarity} = "Quest Item";
  }
  # If the item is an unidentified rare, use the %uniqueInfoHash to see if we can identify it
  if (($item{attributes}{rarity} eq "Unique") && ($item{attributes}{identified} <1)) {
    $data{name} = $uniqueInfoHash{$item{info}{icon}} if ($uniqueInfoHash{$item{info}{icon}});
  }

  # Set the item level
  $item{attributes}{ilvl} = $data{ilvl};
 
  $item{info}{fullName} = $data{name}." ".$data{typeLine}; 
  # Remove the Superior and/or any leading white space from fullName in case we got it somewhere in the merge
  $item{info}{fullName} =~ s/^(Superior |\s+)//o;
  $item{info}{tokenized}{fullName} = lc($item{info}{fullName});
  $item{info}{name} = $data{name};

  $item{info}{name} = $item{info}{fullName} unless ($item{info}{name});
  $item{info}{typeLine} = $data{typeLine};

  if ($data{descrText}) {
    $item{info}{descrText} = $data{descrText};
    $item{info}{tokenized}{descrText} = lc($data{descrText});
  }

  $item{attributes}{corrupted} = $data{corrupted};
  $item{attributes}{support} = $data{support};
  if ($data{duplicated}) {
    $item{attributes}{mirrored} = $data{duplicated};
  } else {
    $item{attributes}{mirrored} = \0;
  }
  if ($data{lockedToCharacter}) {
    $item{attributes}{lockedToCharacter} = $data{lockedToCharacter};
  } else {
    $item{attributes}{lockedToCharacter} = \0;
  }
  $item{attributes}{inventoryWidth} = $data{w};
  $item{attributes}{inventoryHeight} = $data{h};

  foreach my $flava (@{$data{flavourText}}) {
    # I strip the \r out because it doesn't blend well
    $flava =~ s/\r/ /g;
    $item{info}{flavourText} .= $flava;
    $item{info}{tokenized}{flavourText} .= lc($flava);
  }






  local ($item{attributes}{itemType}, $item{attributes}{baseItemType}, $item{attributes}{baseItemName}) = &IdentifyType("");

  # Don't further process items if it is unknown
  if ($item{attributes}{baseItemType} eq "Unknown") {
    my $jsonout = JSON::XS->new->utf8->encode(\%item);
    return($jsonout, $item{uuid}, "Unknown");
  }


  # Determine Item Requirements & Properties

  # I'm not a JSON expert, but the way the JSON is laid out here makes it very difficult to reference.
  # For some sections, like requirements, they're using arrays of hashes with nested arrays, so
  # de-referencing these efficiently can be very tricky. Basically we get to do some weird
  # iteration through stuff to de-reference it.

  my $p = "0";
  # Find each hash in the array under requirements and do stuff with it
  foreach my $pval (@{$data{'requirements'}}) {
#    last unless ($pval); # This isn't strictly necessary, but this loop can hang due to corrupted JSON otherwise
    if ($data{requirements}[$p]{name}) {
      # Set the local requirement name, which is a fixed value in the hash
      my $requirement = $data{requirements}[$p]{name};

      # Standardize some of the attributes stuff - for some reason, some items have Int and other have Intelligence, etc.
      $requirement = "Int" if ($requirement eq "Intelligence");
      $requirement = "Str" if ($requirement eq "Strength");
      $requirement = "Dex" if ($requirement eq "Dexterity");
      # Flatted the name to first uppercase only
      $requirement = ucfirst($requirement);

      # At the time of writing, the actual value is always the first element in the first nested array in the JSON
      # data. I don't know why it's laid out like this, i.e.
      # requirements : [ { values : [ [ "20", 0 ] ] } ]
      my $value = $data{requirements}[$p]{values}[0][0];

      # Add this information to the hash. We use += to ensure it's added as a number and avoid any weird situations
      # where an item has two requirements of the same type causing the value to get lost
      $item{requirements}{$requirement} += $value;
    }
    $p++;
  }

  # Time to do the same for properties, which is also laid out kinda weird
  my $p = "0";
  # Find each hash in the array under requirements and do stuff with it
  foreach my $pval ( @{$data{'properties'}} ) {
#    last unless ($p); # This isn't strictly necessary, but this loop can hang due to corrupted JSON otherwise
    if ($data{properties}[$p]{name}) {
      my $property = $data{properties}[$p]{name};
      my $value = $data{properties}[$p]{values}[0][0];
      $value =~ s/\%//g;
  
      my $isboolean = 0; 
      # Make sure a numeric value of 0 is assigned if the string is 0
      if ($value eq "0") {
        $value += 0;
      } else {
        # Otherwise value wasn't set because no numbers were found in the string, so it's a true/false setting
        unless ($value) {
          $value = \1;
          $isboolean = 1;
        }
      }

      # If the property contains (MAX) (for gems) just remove that portion so it's numeric
      $value =~ s/ \(MAX\)//ig;

      $property =~ s/\%0/#/g;
      $property =~ s/\%1/#/g;

      # Detection for elemental damage types
      # see https://github.com/trackpete/exiletools-indexer/issues/62
      if ($property eq "Elemental Damage") {
        &CreateElementalDamageTypeHash unless (%elementalDamageType);
        my $elep = "0";
        foreach my $eleparr ( @{$data{properties}[$p]{values}} ) {
          my ($min, $max) = split(/\-/, $$eleparr[0]);
          $item{properties}{$item{attributes}{baseItemType}}{"$elementalDamageType{$$eleparr[1]}"}{min} += $min;
          $item{properties}{$item{attributes}{baseItemType}}{"$elementalDamageType{$$eleparr[1]}"}{max} += $max;
          $item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{min} += $min;
          $item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{max} += $max;
          $item{properties}{$item{attributes}{baseItemType}}{"Total Damage"}{min} += $min;
          $item{properties}{$item{attributes}{baseItemType}}{"Total Damage"}{max} += $max;
          # Update averages
          $item{properties}{$item{attributes}{baseItemType}}{"$elementalDamageType{$$eleparr[1]}"}{avg} = sprintf('%.2f', (($item{properties}{$item{attributes}{baseItemType}}{"$elementalDamageType{$$eleparr[1]}"}{min} + $item{properties}{$item{attributes}{baseItemType}}{"$elementalDamageType{$$eleparr[1]}"}{max}) / 2)) * 1;
          $item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{avg} = sprintf('%.2f', (($item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{min} + $item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{max}) / 2)) * 1;
          $item{properties}{$item{attributes}{baseItemType}}{"Total Damage"}{avg} = sprintf('%.2f', (($item{properties}{$item{attributes}{baseItemType}}{"Total Damage"}{min} + $item{properties}{$item{attributes}{baseItemType}}{"Total Damage"}{max}) / 2)) * 1;
        }
      } elsif ($property =~ /One Handed/) {
        $item{attributes}{equipType} = "One Handed Melee Weapon";
        $item{properties}{$item{attributes}{baseItemType}}{type}{$property} = $value;
      } elsif ($property =~ /Two Handed/) {
        $item{attributes}{equipType} = "Two Handed Melee Weapon";
        $item{properties}{$item{attributes}{baseItemType}}{type}{$property} = $value;
      } elsif ($property eq "Quality") {
        $value =~ s/\+//g;
        $item{properties}{$property} = $value;
      } elsif ($property =~ /^(.*?) \%0 (.*?) \%1 (.*?)$/) {
        # If there are some weird parameters here, put them into a subsection for the item type
        # This is pretty much exclusive to flasks
        $item{properties}{$item{attributes}{baseItemType}}{$property}{x} += $data{properties}[$p]{values}[0][0];
        $item{properties}{$item{attributes}{baseItemType}}{$property}{y} += $data{properties}[$p]{values}[1][0];
      } elsif ($value =~ /(\d+)-(\d+)/) {
        my $min = $1;
        my $max = $2;
        $item{properties}{$item{attributes}{baseItemType}}{$property}{min} += $min;
        $item{properties}{$item{attributes}{baseItemType}}{$property}{max} += $max;
        $item{properties}{$item{attributes}{baseItemType}}{$property}{avg} = sprintf('%.2f', (($item{properties}{$item{attributes}{baseItemType}}{$property}{min} + $item{properties}{$item{attributes}{baseItemType}}{$property}{max}) / 2)) * 1;

        if (($property eq "Physical Damage") || ($property eq "Chaos Damage")) {
          $item{properties}{$item{attributes}{baseItemType}}{"Total Damage"}{min} += $min;
          $item{properties}{$item{attributes}{baseItemType}}{"Total Damage"}{max} += $max;
          $item{properties}{$item{attributes}{baseItemType}}{"Total Damage"}{avg} = sprintf('%.2f', (($item{properties}{$item{attributes}{baseItemType}}{"Total Damage"}{min} + $item{properties}{$item{attributes}{baseItemType}}{"Total Damage"}{max}) / 2)) * 1;
        }

      } elsif (($item{attributes}{baseItemType} eq "Gem") && (($property =~ /\,/) || ($isboolean))) {
        if ($property =~ /\,/) {
          my @props = split(/\,/, $property);
          foreach $prop (@props) {
            $prop =~ s/^\s+//g;
            $item{properties}{$item{attributes}{baseItemType}}{type}{$prop} = \1;
          }
        } elsif ($isboolean > 0)  {
          # Assume any boolean in a Gem Property is actually a type
          # see https://github.com/trackpete/exiletools-indexer/issues/52
          $item{properties}{$item{attributes}{baseItemType}}{type}{$property} = \1;
        }
      } elsif (($item{attributes}{baseItemType} eq "Weapon") && ($isboolean > 0))  {
        # Assume any boolean in a Weapon Property is actually a type
        # see https://github.com/trackpete/exiletools-indexer/issues/54
        $item{properties}{$item{attributes}{baseItemType}}{type}{$property} = \1;
      } elsif (($item{attributes}{baseItemType} eq "Map") && ($value =~ /\+/))  {
        # Remove the +'s from map attributes and set them to integers
        # see https://github.com/trackpete/exiletools-indexer/issues/53
        $item{properties}{$item{attributes}{baseItemType}}{$property} += $value;
      } elsif (($property eq "Stack Size") && ($value =~ /^(\d+)\/(\d+)$/)) {
        # Handle Stack Size separately
        $item{properties}{stackSize}{current} += $1;
        $item{properties}{stackSize}{max} += $2;
      } else {
        # Use a string if it's a string, number of it's a number                                                                                                                      
        # Remove " sec" from cast times and cooldown times for gems
        if (($item{attributes}{baseItemType} eq "Gem") && ($property =~ /^\d+(\.\d{1,2}) sec$/)) {
          $property =~ s/ sec$//o;
        }
        if (($value =~ /^\d+$/) || ($value =~ /^\d+(\.\d{1,2})?$/)) {                                                   
          $item{properties}{$item{attributes}{baseItemType}}{$property} += $value;                                                                 
        } else {                                                                                                                                  
          $item{properties}{$item{attributes}{baseItemType}}{$property} = $value;                                                                             
        }                                                                                                                                                      
      }
    } elsif (($data{properties}[$p]{values}[0][0]) && ($data{properties}[$p]{values}[0][1])) {
      my $property = $data{properties}[$p]{values}[0][0];
      my $value = $data{properties}[$p]{values}[0][1];
      # Use a string if it's a string, number of it's a number
      if (($value =~ /^\d+$/) || ($value =~ /^\d+(\.\d{1,2})?$/)) {                                                   
        $item{properties}{$item{attributes}{baseItemType}}{$property} += $value;
      } else {
        $item{properties}{$item{attributes}{baseItemType}}{$property} = $value;
      }
    }
    $p++;
  }

  # If the item is a gem, it may have an additionalProperties for experience, let's log that
  if ($data{additionalProperties}[0]{values}[0][0] =~ /^\d+\/\d+$/) {
    my ($xpCurrent, $xpGoal) = split(/\//, $data{additionalProperties}[0]{values}[0][0]);
    $item{properties}{$item{attributes}{baseItemType}}{Experience}{Current} += $xpCurrent;
    $item{properties}{$item{attributes}{baseItemType}}{Experience}{NextLevel} += $xpGoal;
    $item{properties}{$item{attributes}{baseItemType}}{Experience}{PercentLeveled} += int($xpCurrent / $xpGoal * 100);
  }

  &parseExtendedMods("explicitMods","explicit") if ($data{explicitMods});
  &parseExtendedMods("implicitMods","implicit") if ($data{implicitMods});
  &parseExtendedMods("craftedMods","crafted") if ($data{craftedMods});
  &parseExtendedMods("cosmeticMods","cosmetic") if ($data{cosmeticMods});

  # Enchantments are a little interesting. For now, we're going to assume they are FIXED
  # value mods and set them as boolean true instead of variable range mods.
  # If this turns out to be wrong, we should be able to simply call parseExtendedMods for
  # the enchantMods line
  foreach my $mod (@{$data{enchantMods}}) {
    $item{attributes}{enchantModsCount}++;
# Don't think we actually need this
#    $mod =~ s/\'//g;
    $mod =~ s/\.//g;
    $item{enchantMods}{"$mod"} = \1;
  } 


  # Build Pseudo Mods for Jewels
#  &setJewelPseudoMods if ($item{attributes}{baseItemType} eq "Jewel");

  # If the item is a Weapon, calculate DPS and average flat damage information
  if ($item{attributes}{baseItemType} eq "Weapon") {
    foreach my $damage (keys(%{$item{properties}{Weapon}})) {
      if (($item{properties}{Weapon}{"$damage"}{min} > 0) && ($item{properties}{Weapon}{"$damage"}{max} > 0)) {
        my ($damageType, $damageChaff) = split(/ /, $damage);
        $item{properties}{Weapon}{"$damage"}{avg} = int(($item{properties}{Weapon}{"$damage"}{min} + $item{properties}{Weapon}{"$damage"}{max}) / 2) * 1;

        $item{properties}{Weapon}{"$damageType DPS"} += int($item{properties}{Weapon}{"$damage"}{avg} * $item{properties}{Weapon}{"Attacks per Second"});


      }
    }
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
    } elsif ($item{info}{typeLine} =~ /\bTalisman\b/) {
      $item{attributes}{equipType} = "Talisman";
    } else {
      $item{attributes}{equipType} = $item{attributes}{itemType};
    } 
  }
  
  if ($data{sockets}[0]{attr}) {
    # Kinda hacky
    # https://github.com/trackpete/exiletools-indexer/issues/106
    foreach my $socket (@{$data{sockets}}) {
      if ($socket->{attr} eq "G") {
        $item{sockets}{totalWhite}++;
      } elsif ($socket->{attr} eq "D") {
        $item{sockets}{totalGreen}++;
      } elsif ($socket->{attr} eq "S") {
        $item{sockets}{totalRed}++;
      } elsif ($socket->{attr} eq "I") {
        $item{sockets}{totalBlue}++;
      }
    }

    my %sortGroup;
    ($item{sockets}{largestLinkGroup}, $item{sockets}{socketCount}, $item{sockets}{allSockets}, $item{sockets}{allSocketsSorted}, $item{sockets}{allSocketsGGG}, %sortGroup) = &ItemSockets();
    foreach $sortGroup (keys(%sortGroup)) {
      $item{sockets}{sortedLinkGroup}{$sortGroup} = $sortGroup{$sortGroup};
    }
  }

  # Add a PseudoMod count for total resists
  if ($item{modsPseudo}) {
    foreach $elekey (keys (%{$item{modsPseudo}})) {
      $item{modsPseudo}{"# of Elemental Resistances"}++ if ($elekey =~ /(Cold|Fire|Lightning)/);
      $item{modsPseudo}{"# of Resistances"}++ if ($elekey =~ /(Cold|Fire|Lightning|Chaos)/);
    }
  }

  # Time to try out some quality calculations
  # See https://github.com/trackpete/exiletools-indexer/issues/25
  if ($item{attributes}{baseItemType} eq "Armour") {
    # If this is already 20, we don't have to change anything
    if ($item{properties}{Quality} == 20) {
      foreach my $prop (keys(%{$item{properties}{Armour}})) {
        next if $prop eq "Chance to Block";
        $item{propertiesPseudo}{Armour}{estimatedQ20}{"$prop"} += $item{properties}{Armour}{"$prop"};
      }
    } else {
      # Crap, we have to try to estimate the Q20 values
      foreach my $prop (keys(%{$item{properties}{Armour}})) {
        next if $prop eq "Chance to Block";
        # Does this item have an increased mod?
        if ($item{modsPseudo}{"#% Total increased $prop"} > 0) {
          $item{propertiesPseudo}{Armour}{estimatedQ20}{"$prop"} += int($item{properties}{Armour}{"$prop"} / (1 + ($item{modsPseudo}{"#% Total increased $prop"} + $item{properties}{Quality}) / 100) * (1 + (($item{modsPseudo}{"#% Total increased $prop"} + 20) / 100)));
        } else {
          $item{propertiesPseudo}{Armour}{estimatedQ20}{"$prop"} = int(($item{properties}{Armour}{"$prop"} / (1 + $item{properties}{Quality} / 100)) * 1.20);
        }
      }
    }
  } elsif ($item{attributes}{baseItemType} eq "Weapon") {
    # If this is already 20, we don't have to change anything
    if ($item{properties}{Quality} == 20) {
      $item{propertiesPseudo}{Weapon}{estimatedQ20}{"Physical DPS"} += $item{properties}{Weapon}{"Physical DPS"};
    } else {
      # Crap, we have to try to estimate the Q20 values
      # Does this item have an increased mod?
      if ($item{modsTotal}{"#% increased Physical Damage"} > 0) {
        $item{propertiesPseudo}{Weapon}{estimatedQ20}{"Physical DPS"} += int($item{properties}{Weapon}{"Physical DPS"} / (1 + ($item{modsTotal}{"#% increased Physical Damage"} + $item{properties}{Quality}) / 100) * (1 + (($item{modsTotal}{"#% increased Physical Damage"} + 20) / 100)));
      } else {
        $item{propertiesPseudo}{Weapon}{estimatedQ20}{"Physical DPS"} = int(($item{properties}{Weapon}{"Physical DPS"} / (1 + $item{properties}{Quality} / 100)) * 1.20);
      }
    }
  }



  my $itemStatus;
  if ($itemInES->{uuid}) {
    # If the current note and the stash name are the same, then the item wasn't modified
    if (($itemInES->{shop}->{note} eq $item{shop}{note}) && ($itemInES->{shop}->{stash}->{stashName} eq $item{shop}{stash}{stashName})) {
      $item{shop}{modified} = $itemInES->{shop}->{modified};
      $itemStatus = "Unchanged";
    } else {
      $item{shop}{modified} = time() * 1000;
      $itemStatus = "Modified";
      &sv("i  Modified: $item{shop}{sellerAccount} | $item{info}{fullName} | $item{uuid} | $item{shop}{amount} $item{shop}{currency}\n");
    }
    $item{shop}{updated} = time() * 1000;
    $item{shop}{added} = $itemInES->{shop}->{added};
  } else {
    # It's new!
    $item{shop}{modified} = time() * 1000;
    $item{shop}{updated} = time() * 1000;
    $item{shop}{added} = time() * 1000;
    $itemStatus = "Added";
    &sv("i  Added: $item{shop}{sellerAccount} | $item{info}{fullName} | $item{uuid} | $item{shop}{amount} $item{shop}{currency}\n");
  }

  # Set the price if chaosEquiv is more than 0
  if ($item{shop}{chaosEquiv} > 0) {
    $item{shop}{hasPrice} = \1;
  } else {
    $item{shop}{hasPrice} = \0;
  } 

  # If there is a properties.Weapon.type set, extract the first one and set attributes.weaponType
  if ($item{properties}{Weapon}) {
    my @types = keys(%{$item{properties}{Weapon}{type}});
    $item{attributes}{weaponType} = $types[0];
  }

  # For now, just mark everything as verified since it has to be verified to be listed
  $item{shop}{verified} = "YES";

  # Create a default message
  if ($item{shop}{amount} && $item{shop}{currency}) {
    $item{shop}{defaultMessage} = "\@$item{shop}{lastCharacterName} I would like to buy your $item{info}{fullName} listed for $item{shop}{amount} $item{shop}{currency} (League:$item{attributes}{league}, Stash Tab:\"$item{shop}{stash}{stashName}\" [x$item{shop}{stash}{xLocation},y$item{shop}{stash}{yLocation}])";
  }

  my $jsonout = JSON::XS->new->utf8->encode(\%item);
  if (($JSONLOG) && ($itemStatus ne "Unchanged")) {
    &jsonLOG("$jsonout");
  }
  return($jsonout, $item{uuid}, $itemStatus);
}

sub IdentifyType {
  my $localItemType;
  my $localItemBaseName;
  if ($data{frameType} == 4) {
    $localItemType = "Gem";
  } elsif ($data{frameType} == 6) {
    # frameType has been changed to 6 for Divination Cards and 7 for Quest Items
    # (See https://github.com/trackpete/exiletools-indexer/issues/30)
    # However I'm leaving this code in just in case any weird legacy issues get
    # through
    if ($data{icon} =~ /Divination\/InventoryIcon.png/) {
      $localItemType = "Card";
    } else {
      $localItemType = "Quest Item";
    }
  } elsif ($data{frameType} == 5) {
    $localItemType = "Currency";
  } elsif ($data{frameType} == 7) {
    $localItemType = "Quest Item";
  } elsif ($data{descrText} =~ /Travel to this Map by using it in the Eternal Laboratory/) {
    $localItemType = "Map";
  } elsif ($data{descrText} =~ /Place into an allocated Jewel Socket/) {
    $localItemType = "Jewel";
  } elsif ($data{descrText} =~ /Right click to drink/) {
    $localItemType = "Flask";
  } elsif ($gearBaseType{"$data{typeLine}"}) {
    $localItemType = $gearBaseType{"$data{typeLine}"};
  } else {
    foreach my $gearbase (keys(%gearBaseType)) {
      if ($data{typeLine} =~ /\b$gearbase\b/) {
        $localItemType = $gearBaseType{"$gearbase"};
        $localItemBaseName = $gearbase;
        last;
      }
    }
  }

  # If we didn't match the $localItemBaseName during the iteration above because
  # the frameType wasn't clear, let's match it now
  unless ($localItemBaseName) {
    foreach my $gearbase (keys(%gearBaseType)) {
      if ($data{typeLine} =~ /\b$gearbase\b/) {
        $localItemBaseName = $gearbase;
        last;
      }
    }
    $localItemBaseName = $data{typeLine} unless ($localItemBaseName);
  }

  my $localBaseItemType;

  unless ($localItemType) {
    if ($data{typeLine} =~ /\bTalisman\b/) {
      $localBaseItemType = "Jewelry";
      $localItemType = "Amulet";
    } else {
      $localItemType = "Unknown";
    }
  }

  if ($localItemType =~ /^(Bow|Axe|Sword|Dagger|Mace|Staff|Claw|Sceptre|Wand|Fishing Rod)$/) {
    $localBaseItemType = "Weapon";
  } elsif ($localItemType =~ /^(Helmet|Gloves|Boots|Body|Shield|Quiver)$/) {
    $localBaseItemType = "Armour";
  } elsif ($localItemType =~ /^(Amulet|Belt|Ring)$/) {
    $localBaseItemType = "Jewelry";
  } else {
    $localBaseItemType = $localItemType;
  }
  return($localItemType, $localBaseItemType, $localItemBaseName);
}

sub ItemSockets {
  my %sockets;
  my %sortGroup;

  for (my $socketprop=0;$socketprop <= 10;$socketprop++) {
    my $group = $data{sockets}[$socketprop]{group};
    $sockets{group}{$group} .= $data{sockets}[$socketprop]{attr} if ($data{sockets}[$socketprop]{attr})
  }

  my $socketcount;
  my $allSockets;
  my $allSocketsGGG;
  foreach my $group (sort keys(%{$sockets{group}})) {
#    print "[$threadid][$timestamp] $data[$activeFragment]->[1]{name} Group: $group | Sockets: $sockets{group}{$group} (".length($sockets{group}{$group}).")\n";
    $sockets{maxLinks} = length($sockets{group}{$group}) if (length($sockets{group}{$group}) > $sockets{maxLinks});
    $sockets{count} = $sockets{count} + length($sockets{group}{$group});
  }


  foreach my $group (sort keys(%{$sockets{group}})) {
    $sockets{group}{$group} =~ s/G/W/g;
    $sockets{group}{$group} =~ s/D/G/g;
    $sockets{group}{$group} =~ s/S/R/g;
    $sockets{group}{$group} =~ s/I/B/g;
    $allSockets .= "-$sockets{group}{$group}";
    my $gggGroup = join("-", (split(//, $sockets{group}{$group})));
    $allSocketsGGG .= " $gggGroup";
    my @sort = sort (split(//, $sockets{group}{$group}));
    my $sorted = join("", @sort);
    $sortGroup{$group} = "$sorted";
  }
  $allSockets =~ s/^\-//o;
  $allSocketsGGG =~ s/^\s+//o;

  my @sort = sort (split(//, $allSockets));
  my $sorted = join("", @sort);
  $sorted =~ s/\-//g;
  return($sockets{maxLinks},$sockets{count},$allSockets,$sorted,$allSocketsGGG,%sortGroup);


}

sub setJewelPseudoMods {
  # Iterate through the modsTotal to find known stats.
  # Just experimenting with attack speed for now
  # see https://github.com/trackpete/exiletools-indexer/issues/38

  # Sort them to make sure attack speed goes first
  foreach my $mod (sort keys(%{$item{modsTotal}})) {
    if ($mod =~ /#% increased Attack Speed (.*?)$/) {
      my $desc = $1;
      $item{modsPseudo}{"#% increased Attack Speed $desc"} = $item{modsTotal}{"#% increased Attack Speed"} + $item{modsTotal}{"$mod"};
    }
  }
}

sub setPseudoMods {
  my $modifier = $_[0];
  my $modname = $_[1];
  my $value = $_[2];
  my $othermodifier = $_[3];

  # The code for calculating pseudo mods is a little messy right now.
  # We can proably do this without so many nested ifs

  if ($modname =~ /to (\S+) Resistance/) {
    if ($modname =~ /Chaos/i) {
      if ($modifier eq '+') {
        $item{modsPseudo}{"+#% Total to Resistances"} += $value;
        $item{modsPseudo}{"+#% Total to Chaos Resistance"} += $value;
      } else {
        $item{modsPseudo}{"+#% Total to Resistances"} -= $value;
        $item{modsPseudo}{"+#% Total to Chaos Resistance"} -= $value;
      }
    } else {
      if ($modifier eq '+') {
        $item{modsPseudo}{"+#% Total to Resistances"} += $value;
        $item{modsPseudo}{"+#% Total to Elemental Resistances"} += $value;
        $item{modsPseudo}{"+#% Total to $1 Resistance"} += $value;
      } else {
        $item{modsPseudo}{"+#% Total to Resistances"} -= $value;
        $item{modsPseudo}{"+#% Total to Elemental Resistances"} -= $value;
        $item{modsPseudo}{"+#% Total to $1 Resistance"} -= $value;
      }
    }
  # We're assuming right now there is no "+ to Chaos and Ele" resist mods
  } elsif ($modname =~ /to (\S+) and (\S+) Resistances/) {
    # If the mod adds to resist, add it to the total twice (one for each resist)
    if ($modifier eq '+') {
      $item{modsPseudo}{"+#% Total to Resistances"} += $value + $value;
      $item{modsPseudo}{"+#% Total to Elemental Resistances"} += $value + $value;
      $item{modsPseudo}{"+#% Total to $1 Resistance"} += $value;
      $item{modsPseudo}{"+#% Total to $2 Resistance"} += $value;
    # Same if it subtracts two resists
    } else {
      $item{modsPseudo}{"+#% Total to Elemental Resistances"} -= $value - $value;
      $item{modsPseudo}{"+#% Total to Resistances"} -= $value - $value;
      $item{modsPseudo}{"+#% Total to $1 Resistance"} -= $value;
      $item{modsPseudo}{"+#% Total to $2 Resistance"} -= $value;
    }
  } elsif ($modname =~ /to all Elemental Resistances/) {
    # If the mod adds to resist, add it to the total thrice (one for each resist)
    if ($modifier eq '+') {
      $item{modsPseudo}{"+#% Total to Elemental Resistances"} += $value + $value + $value;
      $item{modsPseudo}{"+#% Total to Resistances"} += $value + $value + $value;
      $item{modsPseudo}{"+#% Total to Fire Resistance"} += $value;
      $item{modsPseudo}{"+#% Total to Cold Resistance"} += $value;
      $item{modsPseudo}{"+#% Total to Lightning Resistance"} += $value;
    # Same if it subtracts all resists
    } else {
      $item{modsPseudo}{"+#% Total to Elemental Resistances"} -= $value - $value - $value;
      $item{modsPseudo}{"+#% Total to Resistances"} -= $value - $value - $value;
      $item{modsPseudo}{"+#% Total to Fire Resistance"} -= $value;
      $item{modsPseudo}{"+#% Total to Cold Resistance"} -= $value;
      $item{modsPseudo}{"+#% Total to Lightning Resistance"} -= $value;
    }
  } elsif ($modname =~ /to Intelligence$/) {
    $item{modsPseudo}{"+# Total to Attributes"} += $value;
    $item{modsPseudo}{"+# Total to Intelligence"} += $value;
  } elsif ($modname =~ /to Dexterity$/) {
    $item{modsPseudo}{"+# Total to Attributes"} += $value;
    $item{modsPseudo}{"+# Total to Dexterity"} += $value;
  } elsif ($modname =~ /to Strength$/) {
    $item{modsPseudo}{"+# Total to Attributes"} += $value;
    $item{modsPseudo}{"+# Total to Strength"} += $value;
    $item{modsPseudo}{"+# Total to maximum Life"} += int($value / 2);
  } elsif ($modname =~ /to Strength and Intelligence$/) {
    $item{modsPseudo}{"+# Total to Attributes"} += $value;
    $item{modsPseudo}{"+# Total to Attributes"} += $value;
    $item{modsPseudo}{"+# Total to Strength"} += $value;
    $item{modsPseudo}{"+# Total to Intelligence"} += $value;
    $item{modsPseudo}{"+# Total to maximum Life"} += int($value / 2);
  } elsif ($modname =~ /to Dexterity and Intelligence$/) {
    $item{modsPseudo}{"+# Total to Attributes"} += $value;
    $item{modsPseudo}{"+# Total to Attributes"} += $value;
    $item{modsPseudo}{"+# Total to Dexterity"} += $value;
    $item{modsPseudo}{"+# Total to Intelligence"} += $value;
  } elsif ($modname =~ /to Strength and Dexterity/) {
    $item{modsPseudo}{"+# Total to Attributes"} += $value;
    $item{modsPseudo}{"+# Total to Attributes"} += $value;
    $item{modsPseudo}{"+# Total to Strength"} += $value;
    $item{modsPseudo}{"+# Total to Dexterity"} += $value;
    $item{modsPseudo}{"+# Total to maximum Life"} += int($value / 2);
  } elsif ($modname =~ /to all Attributes/) {
    $item{modsPseudo}{"+# Total to Attributes"} += $value;
    $item{modsPseudo}{"+# Total to Attributes"} += $value;
    $item{modsPseudo}{"+# Total to Attributes"} += $value;
    $item{modsPseudo}{"+# Total to Strength"} += $value;
    $item{modsPseudo}{"+# Total to Dexterity"} += $value;
    $item{modsPseudo}{"+# Total to Intelligence"} += $value;
    $item{modsPseudo}{"+# Total to maximum Life"} += int($value / 2);
  } elsif ($modname =~ /to maximum Life/) {
    $item{modsPseudo}{"+# Total to maximum Life"} += $value;
  } elsif ($othermodifier eq "%" && $modname =~ /increased/) {
    if ($modname eq "increased Armour") {
      $item{modsPseudo}{"#% Total increased Armour"} += $value;
    } elsif ($modname eq "increased Evasion Rating") {
      $item{modsPseudo}{"#% Total increased Evasion Rating"} += $value;
    } elsif ($modname eq "increased Energy Shield") {
      $item{modsPseudo}{"#% Total increased Energy Shield"} += $value;
    } elsif ($modname eq "increased Armour and Energy Shield") {
      $item{modsPseudo}{"#% Total increased Armour"} += $value;
      $item{modsPseudo}{"#% Total increased Energy Shield"} += $value;
    } elsif ($modname eq "increased Armour and Evasion") {
      $item{modsPseudo}{"#% Total increased Armour"} += $value;
      $item{modsPseudo}{"#% Total increased Evasion Rating"} += $value;
    } elsif ($modname eq "increased Armour, Evasion and Energy Shield") {
      $item{modsPseudo}{"#% Total increased Armour"} += $value;
      $item{modsPseudo}{"#% Total increased Energy Shield"} += $value;
      $item{modsPseudo}{"#% Total increased Evasion Rating"} += $value;
    } elsif ($modname eq "increased Evasion and Energy Shield") {
      $item{modsPseudo}{"#% Total increased Evasion Rating"} += $value;
      $item{modsPseudo}{"#% Total increased Energy Shield"} += $value;
    }



  }

}

sub parseExtendedMods {
  # i.e. explicitMods
  my $modTypeJSON = $_[0];
  # i.e. explicit
  my $modType = $_[1];
  return unless (($modTypeJSON) && ($modType));

  foreach my $modLine ( @{$data{"$modTypeJSON"}} ) {
    # Remove any apostrophes or periods
    $modLine =~ s/\'//g;
    $modLine =~ s/\.//g;

    # Parsing for Divination cards has to be done a bit differently from other items
    if ($item{attributes}{itemType} eq "Card") {
      # clear any <size:#>{} crap out
      # oh but those stupid close } may be on another line, nice. WTF.
      $modLine =~ s/^\<size:\d+\>\{(.*?)/$1/o;
      $modLine =~ s/\}\}/\}/o;


      # if there's a default line, it's probably a secondary mod with more information, added it to the reward information
      if ($modLine =~ /^\<default\>\{(.*?):*\}\s+\<(.*?)\>\{(.*?)\}\r*$/) {
        $item{mods}{$item{attributes}{itemType}}{DivinationReward} = $item{mods}{$item{attributes}{itemType}}{DivinationReward}." ($1: $3)";
# Removed per https://github.com/trackpete/exiletools-indexer/issues/28
#        $item{modsTotal}{DivinationReward} = $item{modsTotal}{DivinationReward}." ($1: $3)";
        $item{info}{tokenized}{DivinationReward} = lc($item{info}{tokenized}{DivinationReward}." ($1: $3)");

      # The corrupted line should be treated differently
      } elsif ($modLine =~ /^\<corrupted\>\{Corrupted\}\r*$/) {
        $item{mods}{$item{attributes}{itemType}}{DivinationReward} = $item{mods}{$item{attributes}{itemType}}{DivinationReward}." (Corrupted)";
# Removed per https://github.com/trackpete/exiletools-indexer/issues/28
#        $item{modsTotal}{DivinationReward} = $item{modsTotal}{DivinationReward}." (Corrupted)";
        $item{info}{tokenized}{DivinationReward} = lc($item{info}{tokenized}{DivinationReward}." (Corrupted)");

      # if the item is a divination card, it may have a <tag>{reward} line
      } elsif ($modLine =~ /^\<(.*?)\>\{(.*?)\}\r*$/) {
        $item{mods}{$item{attributes}{itemType}}{DivinationReward} = "$1: $2";
# Removed per https://github.com/trackpete/exiletools-indexer/issues/28
#        $item{modsTotal}{DivinationReward} = "$1: $2";
        $item{attributes}{"$modTypeJSON"."Count"}++;
        # Allows tokenized search to match this so you can search for "kaom" in the info.tokenized.DivinationReward field
        $item{info}{tokenized}{DivinationReward} = lc("$1: $2");
      }
    } else {
      # Ignore known bad mods for threshold jewels, see https://github.com/trackpete/exiletools-indexer/issues/23
      if (($modLine eq "Rarity of Items dropped by Enemies Shattered by Glacial Hammer") || ($modLine eq "has a 20% increased angle") || ($modLine eq "has a 25% chance to grant a Power Charge on Kill") || ($modLine eq "10% chance to deal Double Damage") || ($modLine eq "also Fortifies Nearby Allies for 3 seconds")) {
        return;
      # Process the line if it starts with a +/- flat number (i.e. "+1 to Magical Unicorns" becomes (+)(1) (to Magical Unicorns)
      } elsif ($modLine =~ /^(\+|\-)?(\d+(\.\d+)?)(\%?)\s+(.*)$/) {
        my $modname = $5;
        my $value = $2;
        $modname =~ s/\s+$//g;
        $item{mods}{$item{attributes}{itemType}}{$modType}{"$1#$4 $modname"} += $value;
        $item{attributes}{"$modTypeJSON"."Count"}++;
        &setPseudoMods("$1","$modname","$value", "$4");
        unless (($modType eq "cosmetic") || ($item{attributes}{itemType} eq "Gem") || ($item{attributes}{itemType} eq "Map") || $item{attributes}{itemType} eq "Flask") {
          $item{modsTotal}{"$1#$4 $modname"} += $value;
        }

      # Detect threshold jewel modifers and set them as boolean
      } elsif ($modLine =~ /^(With at least .*?)$/) {
        my $thresholdMod = $1;

        # Custom detection for broken multi-line threshold mods
        # See https://github.com/trackpete/exiletools-indexer/issues/23

        if ($thresholdMod eq "With at least 50 Strength Allocated in radius, Vigilant Strike") {
          $thresholdMod = "With at least 50 Strength Allocated in radius, Vigilant Strike also Fortifies Nearby Allies for 3 seconds";
        } elsif ($thresholdMod eq "With at least 50 Strength Allocated in Radius, Heavy Strike has a ") {
          $thresholdMod = "With at least 50 Strength Allocated in Radius, Heavy Strike has a 10% chance to deal Double Damage";
        } elsif ($thresholdMod eq "With at least 50 Intelligence Allocated in radius, Cold Snap") {
          $thresholdMod = "With at least 50 Intelligence Allocated in radius, Cold Snap has a 25% chance to grant a Power Charge on Kill";
        } elsif ($thresholdMod eq "With at least 50 Strength Allocated in radius, Ground Slam") {
          $thresholdMod = "With at least 50 Strength Allocated in radius, Ground Slam has a 20% increased angle";
        } elsif ($thresholdMod eq "With at least 50 Strength Allocated in Radius, 20% increased") {
          $thresholdMod = "With at least 50 Strength Allocated in Radius, 20% increased Rarity of Items dropped by Enemies Shattered by Glacial Hammer";
        }

        $item{mods}{$item{attributes}{itemType}}{$modType}{"$thresholdMod"} = \1;

      # Look for lines with numbers elsewhere, such as "Adds 1 additional Magic Unicorn" or "Increased life by 10%"
      } elsif ($modLine =~ /^(.*?) (\+?\d+(\.\d+)?(-\d+(\.\d+)?)?%?)\s?(.*)$/) {
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
        if ($val =~ /Unique Boss deals +(.*?)\% Damage and attacks +(.*?)% faster/) {
          $value = "$1-$2";
          $modname = "Unique Boss deals %# Damage and attacks %# faster";
        }
        if ($value =~ /(\d+)-(\d+)/) {
          $item{mods}{$item{attributes}{itemType}}{$modType}{$modname}{min} += $1;
          $item{mods}{$item{attributes}{itemType}}{$modType}{$modname}{max} += $2;
          $item{mods}{$item{attributes}{itemType}}{$modType}{$modname}{avg} = sprintf('%.2f', (($item{mods}{$item{attributes}{itemType}}{$modType}{$modname}{min} + $item{mods}{$item{attributes}{itemType}}{$modType}{$modname}{max}) /2)) * 1;
          
          unless (($modType eq "cosmetic") || ($item{attributes}{itemType} eq "Gem") || ($item{attributes}{itemType} eq "Map") || $item{attributes}{itemType} eq "Flask") {
            $item{modsTotal}{$modname}{min} += $1;
            $item{modsTotal}{$modname}{max} += $2;
            $item{modsTotal}{$modname}{avg} = sprintf('%.2f', (($item{modsTotal}{$modname}{min} + $item{modsTotal}{$modname}{max}) / 2 )) * 1;
          }
   
        } else {
          $item{mods}{$item{attributes}{itemType}}{$modType}{$modname} += $value;
          unless (($modType eq "cosmetic") || ($item{attributes}{itemType} eq "Gem") || ($item{attributes}{itemType} eq "Map") || $item{attributes}{itemType} eq "Flask") {
            $item{modsTotal}{$modname} += $value;
          }
        }
        $item{attributes}{"$modTypeJSON"."Count"}++;
      # Anything left over, just assume that it's a description that should be set to TRUE
      } else {
        $item{mods}{$item{attributes}{itemType}}{$modType}{$modLine} = \1;
# Skip booleans for modsTotal too
#        unless (($modType eq "cosmetic") || ($item{attributes}{itemType} eq "Gem") || ($item{attributes}{itemType} eq "Map") || $item{attributes}{itemType} eq "Flask") {
#          $item{modsTotal}{$modLine} = \1;
#        }
        $item{attributes}{"$modTypeJSON"."Count"}++;
      }
    }
  }
}

sub CreateElementalDamageTypeHash {
  our %elementalDamageType;

  $elementalDamageType{1} = "Physical Damage";
  $elementalDamageType{4} = "Fire Damage";
  $elementalDamageType{5} = "Cold Damage";
  $elementalDamageType{6} = "Lightning Damage";
  $elementalDamageType{7} = "Chaos Damage";
}

return true;

