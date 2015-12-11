#!/usr/bin/perl

require('subs/sub.uniqueItemInfoHash.pl');

sub formatJSON {
  # Decode any diacritics and unicode junk in the JSON data for simplicity - everyone just types "mjolner" etc.
  my $rawjson = unidecode($_[0]);

  # De-reference the hash for simplicity
  $json = JSON::XS->new->utf8->pretty->allow_nonref;
  %data = %{$json->decode($rawjson)};

  $item{attributes}{league} = $data{league};
  return("FAIL: Unknown League") if ($data{league} eq "Unknown");
  $item{attributes}{identified} = $data{identified};
  $item{info}{icon} = $data{icon};
  # Strip anything after a ? from it, no need to have forced dimensions
  $item{info}{icon} =~ s/\?.*$//g;

  # Remove the Superior and/or any leading white space from typeLine
  $data{typeLine} =~ s/^(Superior |\s+)//o;

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






  local ($localItemType, $localBaseItemType) = &IdentifyType("");
  $item{attributes}{baseItemType} = $localBaseItemType;
  $item{attributes}{itemType} = $localItemType;

  # Don't further process items if it is unknown
  if ($item{attributes}{baseItemType} eq "Unknown") {
    my $jsonout = JSON::XS->new->utf8->encode(\%item);
    return($jsonout);
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

      if ($property =~ /One Handed/) {
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
        $item{properties}{$item{attributes}{baseItemType}}{$property}{min} += $1;
        $item{properties}{$item{attributes}{baseItemType}}{$property}{max} += $2;
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
      } else {                                                                                                                                                                        
        # Use a string if it's a string, number of it's a number                                                                                                                      
        if ($value =~ /^\d+$/) {                                                   
          $item{properties}{$item{attributes}{baseItemType}}{$property} += $value;                                                                 
        } else {                                                                                                                                  
          $item{properties}{$item{attributes}{baseItemType}}{$property} = $value;                                                                             
        }                                                                                                                                                      
      }
    } elsif (($data{properties}[$p]{values}[0][0]) && ($data{properties}[$p]{values}[0][1])) {
      my $property = $data{properties}[$p]{values}[0][0];
      my $value = $data{properties}[$p]{values}[0][1];
      # Use a string if it's a string, number of it's a number
      if ($value =~ /^\d+$/) {
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

  # If the item is a Weapon, calculate DPS information
  if ($item{attributes}{baseItemType} eq "Weapon") {

    # Calculate DPS
    if ($item{properties}{$item{attributes}{baseItemType}}{"Physical Damage"}) {
      if (($item{properties}{$item{attributes}{baseItemType}}{"Physical Damage"}{min} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Physical Damage"}{max} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"} > 0)) {
        $item{properties}{$item{attributes}{baseItemType}}{"Physical DPS"} += int(($item{properties}{$item{attributes}{baseItemType}}{"Physical Damage"}{min} + $item{properties}{$item{attributes}{baseItemType}}{"Physical Damage"}{max}) / 2 * $item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"});
      }
    }
    if ($item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}) {
      if (($item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{min} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{max} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"} > 0)) {
        $item{properties}{$item{attributes}{baseItemType}}{"Elemental DPS"} += int(($item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{min} + $item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{max}) / 2 * $item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"});
      }
    }
    if ($item{properties}{$item{attributes}{baseItemType}}{"Chaos Damage"}) {
      if (($item{properties}{$item{attributes}{baseItemType}}{"Chaos Damage"}{min} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Chaos Damage"}{max} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"} > 0)) {
        $item{properties}{$item{attributes}{baseItemType}}{"Chaos DPS"} += int(($item{properties}{$item{attributes}{baseItemType}}{"Chaos Damage"}{min} + $item{properties}{$item{attributes}{baseItemType}}{"Chaos Damage"}{max}) / 2 * $item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"});
      }
    }
    if ($item{properties}{$item{attributes}{baseItemType}}{"Physical DPS"} || $item{properties}{$item{attributes}{baseItemType}}{"Elemental DPS"} || $item{properties}{$item{attributes}{baseItemType}}{"Chaos DPS"}) {
      $item{properties}{$item{attributes}{baseItemType}}{"Total DPS"} += $item{properties}{$item{attributes}{baseItemType}}{"Physical DPS"} + $item{properties}{$item{attributes}{baseItemType}}{"Elemental DPS"} + $item{properties}{$item{attributes}{baseItemType}}{"Chaos DPS"};
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
    my %sortGroup;
    ($item{sockets}{largestLinkGroup}, $item{sockets}{socketCount}, $item{sockets}{allSockets}, $item{sockets}{allSocketsSorted}, %sortGroup) = &ItemSockets();
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

  my $jsonout = JSON::XS->new->utf8->encode(\%item);
  return($jsonout);
}

sub IdentifyType {
  my $localBaseItemType;
  if ($data{frameType} == 4) {
    $localBaseItemType = "Gem";
  } elsif ($data{frameType} == 6) {
    # frameType has been changed to 6 for Divination Cards and 7 for Quest Items
    # (See https://github.com/trackpete/exiletools-indexer/issues/30)
    # However I'm leaving this code in just in case any weird legacy issues get
    # through
    if ($data{icon} =~ /Divination\/InventoryIcon.png/) {
      $localBaseItemType = "Card";
    } else {
      $localBaseItemType = "Quest Item";
    }
  } elsif ($data{frameType} == 5) {
    $localBaseItemType = "Currency";
  } elsif ($data{frameType} == 7) {
    $localBaseItemType = "Quest Item";
  } elsif ($data{descrText} =~ /Travel to this Map by using it in the Eternal Laboratory/) {
    $localBaseItemType = "Map";
  } elsif ($data{descrText} =~ /Place into an allocated Jewel Socket/) {
    $localBaseItemType = "Jewel";
  } elsif ($data{descrText} =~ /Right click to drink/) {
    $localBaseItemType = "Flask";
  } elsif ($gearBaseType{"$data{typeLine}"}) {
    $localBaseItemType = $gearBaseType{"$data{typeLine}"};
  } else {
    foreach my $gearbase (keys(%gearBaseType)) {
      if ($data{typeLine} =~ /\b$gearbase\b/) {
        &sv("Matched $data{typeLine} to $gearbase\n");
        $localBaseItemType = $gearBaseType{"$gearbase"};
        last;
      }
    }
  }
  unless ($localBaseItemType) {
    if ($data{typeLine} =~ /\bTalisman\b/) {
      $localBaseItemType = "Talisman";
    } else {
      $localBaseItemType = "Unknown";
    }
  }

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
    my $group = $data{sockets}[$socketprop]{group};
    $sockets{group}{$group} .= $data{sockets}[$socketprop]{attr} if ($data{sockets}[$socketprop]{attr})
  }

  my $socketcount;
  my $allSockets;
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
  }
}

sub parseExtendedMods {
  # i.e. explicitMods
  my $modTypeJSON = $_[0];
  # i.e. explicit
  my $modType = $_[1];
  return unless (($modTypeJSON) && ($modType));

  foreach my $modLine ( @{$data{"$modTypeJSON"}} ) {
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
      # Process the line if it starts with a +/- flat number (i.e. "+1 to Magical Unicorns" becomes (+)(1) (to Magical Unicorns)
      if ($modLine =~ /^(\+|\-)?(\d+(\.\d+)?)(\%?)\s+(.*)$/) {
        my $modname = $5;
        my $value = $2;
        $modname =~ s/\s+$//g;
        $item{mods}{$item{attributes}{itemType}}{$modType}{"$1#$4 $modname"} += $value;
        $item{attributes}{"$modTypeJSON"."Count"}++;
        &setPseudoMods("$1","$modname","$value");
        unless (($modType eq "cosmetic") || ($item{attributes}{itemType} eq "Gem") || ($item{attributes}{itemType} eq "Map") || $item{attributes}{itemType} eq "Flask") {
          $item{modsTotal}{"$1#$4 $modname"} += $value;
        }
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
          
          unless (($modType eq "cosmetic") || ($item{attributes}{itemType} eq "Gem") || ($item{attributes}{itemType} eq "Map") || $item{attributes}{itemType} eq "Flask") {
            $item{modsTotal}{$modname}{min} += $1;
            $item{modsTotal}{$modname}{max} += $2;
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

return true;

