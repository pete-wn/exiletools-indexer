#!/usr/bin/perl

sub formatJSON {
  my $rawjson = $_[0];
  $json = JSON::XS->new->utf8->pretty->allow_nonref;
  # De-reference the hash for simplicity
  %data = %{$json->decode("$rawjson")};
  
  $item{info}{fullName} = $data{name}." ".$data{typeLine}; 
  $item{info}{fullName} =~ s/^Superior//g;
  $item{info}{fullName} =~ s/^\s+//g;
  $item{info}{fullName} =~ s/Maelst(.*?)m/Maelstrom/g;
  $item{info}{fullName} =~ s/Mj(.*?)lner/Mjolner/g;
  $item{info}{fullName} =~ s/Ngamahu(.*?)s Sign/Ngamahu\'s Sign/g;
  $item{info}{fullName} =~ s/Tasalio(.*?)s Sign/Tasalio\'s Sign/g;
  $item{info}{fullNameTokenized} = $item{info}{fullName};


  $item{info}{name} = $data{name};
  $item{info}{name} =~ s/Maelst(.*?)m/Maelstrom/g;
  $item{info}{name} =~ s/Mj(.*?)lner/Mjolner/g;
  $item{info}{name} =~ s/Ngamahu(.*?)s Sign/Ngamahu\'s Sign/g;
  $item{info}{name} =~ s/Tasalio(.*?)s Sign/Tasalio\'s Sign/g;

  $item{info}{name} = $item{info}{fullName} unless ($item{info}{name});
  $item{info}{typeLine} = $data{typeLine};
  $item{info}{descrText} = $data{descrText};

  $item{info}{flavourText} = $data{flavourText};

  $data{icon} =~ /(.*?)\?/;
  $item{info}{icon} = $1;
  $item{attributes}{corrupted} = $data{corrupted};
  $item{attributes}{support} = $data{support};
  $item{attributes}{identified} = $data{identified};
  $item{attributes}{frameType} = $data{frameType};
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
    $item{attributes}{rarity} = "Quest Item";
  }



  $item{attributes}{league} = $data{league};
  local ($localItemType, $localBaseItemType) = &IdentifyType("");
  $item{attributes}{baseItemType} = $localBaseItemType;
  $item{attributes}{itemType} = $localItemType;

  # Determine Item Requirements & Properties

  # I'm not a JSON expert, but the way the JSON is laid out here makes it very difficult to reference.
  # For some sections, like requirements, they're using arrays of hashes with nested arrays, so
  # de-referencing these efficiently can be very tricky. Basically we get to do some weird
  # iteration through stuff to de-reference it.

  my $p = "0";
  # Find each hash in the array under requirements and do stuff with it
  foreach my $pval ( @{$data{'requirements'}} ) {
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
      $value = \1 unless ($value);

      $property =~ s/\%0/#/g;
      $property =~ s/\%1/#/g;

      if ($data{properties}[$p]{name} =~ /One Handed/) {
        $item{attributes}{equipType} = "One Handed Melee Weapon";
      } elsif ($data{properties}[$p]{name} =~ /Two Handed/) {
        $item{attributes}{equipType} = "Two Handed Melee Weapon";
      } elsif ($data{properties}[$p]{name} eq "Quality") {
        $value =~ s/\+//g;
      } elsif ($data{properties}[$p]{name} =~ /^(.*?) \%0 (.*?) \%1 (.*?)$/) {
        $item{properties}{$item{attributes}{baseItemType}}{$property}{x} += $data{properties}[$p]{values}[0][0];
        $item{properties}{$item{attributes}{baseItemType}}{$property}{y} += $data{properties}[$p]{values}[1][0];
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
    } elsif (($data{properties}[$p]{values}[0][0]) && ($data{properties}[$p]{values}[0][1])) {
      my $property = $data{properties}[$p]{values}[0][0];
      my $value = $data{properties}[$p]{values}[0][1];
      $item{properties}{$item{attributes}{baseItemType}}{$property} += $value;
    }
    $p++;
  }

  # If the item is a Weapon, calculate DPS information
  if ($item{attributes}{baseItemType} eq "Weapon") {

  # Calculate DPS
  if (($item{properties}{$item{attributes}{baseItemType}}{"Physical Damage"}{min} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Physical Damage"}{max} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"} > 0)) {
    $item{properties}{$item{attributes}{baseItemType}}{"Physical DPS"} += int(($item{properties}{$item{attributes}{baseItemType}}{"Physical Damage"}{min} + $item{properties}{$item{attributes}{baseItemType}}{"Physical Damage"}{max}) / 2 * $item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"});
  }
#  if (($item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{min} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{max} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"} > 0)) {
#    $item{properties}{$item{attributes}{baseItemType}}{"Elemental DPS"} += int(($item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{min} + $item{properties}{$item{attributes}{baseItemType}}{"Elemental Damage"}{max}) / 2 * $item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"});
#  }
#  if (($item{properties}{$item{attributes}{baseItemType}}{"Chaos Damage"}{min} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Chaos Damage"}{max} > 0) && ($item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"} > 0)) {
#    $item{properties}{$item{attributes}{baseItemType}}{"Chaos DPS"} += int(($item{properties}{$item{attributes}{baseItemType}}{"Chaos Damage"}{min} + $item{properties}{$item{attributes}{baseItemType}}{"Chaos Damage"}{max}) / 2 * $item{properties}{$item{attributes}{baseItemType}}{"Attacks per Second"});
#  }
#  if ($item{properties}{$item{attributes}{baseItemType}}{"Physical DPS"} || $item{properties}{$item{attributes}{baseItemType}}{"Elemental DPS"} || $item{properties}{$item{attributes}{baseItemType}}{"Chaos DPS"}) {
#    $item{properties}{$item{attributes}{baseItemType}}{"Total DPS"} += $item{properties}{$item{attributes}{baseItemType}}{"Physical DPS"} + $item{properties}{$item{attributes}{baseItemType}}{"Elemental DPS"} + $item{properties}{$item{attributes}{baseItemType}}{"Chaos DPS"};
#  }
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
  
  if ($data{sockets}[0]{attr}) {
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

  my $jsonout = JSON::XS->new->utf8->encode(\%item);
  return($jsonout);
}

sub IdentifyType {
  my $localBaseItemType;
  if ($data{frameType} == 4) {
    $localBaseItemType = "Gem";
  } elsif ($data{frameType} == 6) {
    if ($data{icon} =~ /Divination\/InventoryIcon.png/) {
      $localBaseItemType = "Card";
    } else {
      $localBaseItemType = "Quest Item";
    }
  } elsif ($data{frameType} == 5) {
    $localBaseItemType = "Currency";
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
      if ($data{typeLine} =~ /$gearbase/) {
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

return true;
