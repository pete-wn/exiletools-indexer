# Using this to keep track of what I've ported to node, heh.



        # ====== GENERAL ITEM INFORMATION PARSING ======================================
#        $item{shop}{sellerAccount} = $stash{accountName};
#        $item{shop}{stash}{stashID} = $stash{id};
#        $item{shop}{stash}{stashName} = $stash{stash};
#        $item{shop}{lastCharacterName} = $stash{lastCharacterName};
#        $item{shop}{stash}{inventoryID} = $data->{inventoryId};
#        $item{shop}{stash}{xLocation} += $data->{x};
#        $item{shop}{stash}{yLocation} += $data->{y};
#        $item{attributes}{inventoryWidth} = $data->{w};
#        $item{attributes}{inventoryHeight} = $data->{h};
#        $item{uuid} = $data->{id};
#        $item{shop}{note} = $data->{note} if ($data->{note});
#        $item{attributes}{league} = $data->{league};
#        $item{attributes}{identified} = $data->{identified};
#        $item{attributes}{corrupted} = $data->{corrupted};
#        $item{attributes}{support} = $data->{support} if ($data->{support});
#        $item{attributes}{ilvl} = $data->{ilvl};
#        $item{attributes}{frameType} = $data->{frameType};
# Set the item rarity based on frameType digit
#        $item{attributes}{rarity} = $frameTypeHash{"$data->{frameType}"};
      
        # If the item has talismanTier data over 1, add that
#        $item{attributes}{talismanTier} = $data->{talismanTier} if ($data->{talismanTier} > 0);
      
        # Item URL, slightly modified
#        $item{info}{icon} = $data->{icon};
        # Strip anything after a ? from it, no need to have forced dimensions
#        $item{info}{icon} =~ s/\?.*$//g;
      
        # For now, just mark everything as verified since it has to be verified to be listed
#        $item{shop}{verified} = "YES";
      
        # Remove the Superior and/or any leading white space from typeLine
#        $data->{typeLine} =~ s/^(Superior |\s+)//o;

      
#        if ($data->{name} && $data->{typeLine}) {
#          $item{info}{fullName} = $data->{name}." ".$data->{typeLine};
#          $item{info}{name} = $data->{name};
#          $item{info}{typeLine} = $data->{typeLine};
#        } elsif ($data->{typeLine}) {
#          $item{info}{typeLine} = $data->{typeLine};
#          $item{info}{fullName} = $data->{typeLine};
#        } elsif ($data->{name}) {
#          $item{info}{fullName} = $data->{name};
#          $item{info}{name} = $data->{name};
#        }
        $item{info}{tokenized}{fullName} = lc($item{info}{fullName});
      
      
        # If the item is an unidentified rare, use the %uniqueInfoHash to see if we can identify it
        if (($item{attributes}{rarity} eq "Unique") && ($item{attributes}{identified} <1)) {
          $data->{name} = $uniqueInfoHash{$item{info}{icon}} if ($uniqueInfoHash{$item{info}{icon}});
        }
      
#        if ($data->{descrText}) {
#          $item{info}{descrText} = $data->{descrText};
#          $item{info}{tokenized}{descrText} = lc($data->{descrText});
#        }
#        if ($data->{prophecyText}) {
#          $item{info}{prophecyText} = $data->{prophecyText};
#          $item{info}{tokenized}{prophecyText} = lc($data->{prophecyText});
#        }
      
        if ($data->{duplicated}) {
          $item{attributes}{mirrored} = $data->{duplicated};
        } else {
          $item{attributes}{mirrored} = \0;
        }
      
#        if ($data->{lockedToCharacter}) {
#          $item{attributes}{lockedToCharacter} = $data->{lockedToCharacter};
#        } else {
#          $item{attributes}{lockedToCharacter} = \0;
#        }
      
        foreach my $flava (@{$data->{flavourText}}) {
          # I strip the \r out because it doesn't blend well
          $flava =~ s/\r/ /g;
          $item{info}{flavourText} .= $flava;
          $item{info}{tokenized}{flavourText} .= lc($flava);
        }
      
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
      
        # ======= PRICE PRICE PRICE ==============================
      
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
          }
      
          if ($priceAmount > 0) {
            $item{shop}{amount} += $priceAmount;
            $item{shop}{price}{"$standardCurrency"} += $priceAmount;
            $item{shop}{chaosEquiv} += &StandardizeCurrency("$priceAmount","$standardCurrency");
          }
      
          $item{shop}{currency} = $standardCurrency if ($standardCurrency);
          $item{shop}{saleType} = $priceType;
          $item{shop}{priceSource} = "note";
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
          }
          if ($priceAmount > 0) {
            $item{shop}{amount} += $priceAmount;
            $item{shop}{price}{"$standardCurrency"} += $priceAmount;
            $item{shop}{chaosEquiv} += &StandardizeCurrency("$priceAmount","$standardCurrency");
          }
          $item{shop}{currency} = $standardCurrency if ($standardCurrency);
          $item{shop}{saleType} = $priceType;
          $item{shop}{priceSource} = "stashName";
        } else {
          $item{shop}{saleType} = "Offer";
        }
      
        # Set the price if chaosEquiv is more than 0
        if ($item{shop}{chaosEquiv} > 0) {
          $item{shop}{hasPrice} = \1;
        } else {
          $item{shop}{hasPrice} = \0;
        } 
      
        # ===== ITEM IDENTIFICATION ================================
        #
      
        if ($data->{frameType} < 4) {
          # normal, magic, rare, and unique items need to be extracted
#          if ($data->{descrText} =~ /Travel to this Map by using it in the Eternal Laboratory/) {
#            $item{attributes}{itemType} = "Map";
#            $item{attributes}{baseItemType} = "Map";
#            $item{attributes}{baseItemName} = "A Map";
          } elsif ($data->{descrText} =~ /Place into an allocated Jewel Socket/) {
            $item{attributes}{itemType} = "Jewel";
            $item{attributes}{baseItemType} = "Jewel";
            if ($gearBaseType{"$data->{typeLine}"}) {
              $item{attributes}{baseItemName} = $data->{typeLine};
            } else {
              foreach my $gearbase (@gearBaseTypeArrayJewel) {
                if ($data->{typeLine} =~ /\b$gearbase\b/) {
                  $item{attributes}{baseItemName} = $gearbase;
                  last;
                }
              }
            }
          } elsif ($data->{descrText} =~ /Right click to drink/) {
            $item{attributes}{itemType} = "Flask";
            $item{attributes}{baseItemType} = "Flask";
            if ($gearBaseType{"$data->{typeLine}"}) {
              $item{attributes}{baseItemName} = $data->{typeLine};
            } else {
              foreach my $gearbase (@gearBaseTypeArrayFlask) {
                if ($data->{typeLine} =~ /\b$gearbase\b/) {
                  $item{attributes}{baseItemName} = $gearbase;
                  last;
                }
              }
            }
          } elsif ($gearBaseType{$data->{typeLine}}) {
            $item{attributes}{itemType} = $gearBaseType{"$data->{typeLine}"};
            $item{attributes}{baseItemType} = $gearBaseType{"$data->{typeLine}"};
            $item{attributes}{baseItemName} = $data->{typeLine};
          } elsif ($data->{descrText} =~ /Can be used in the Eternal Laboratory or a personal Map Device/) {
            # Prophecy Key Fragments, Vaal Fragments should get matched by the previous line
            $item{attributes}{itemType} = "Map Fragment";
            $item{attributes}{baseItemType} = "Map Fragment";
            $item{attributes}{baseItemName} = $data->{typeLine};
          } else {
            # This is one of many items that for some reason has extra text in the typeLine, rendering that
            # line meaningless. This means we need to identify it.
            
            foreach my $gearbase (@gearBaseTypeArrayGear) {
              if ($data->{typeLine} =~ /\b$gearbase\b/) {
                $item{attributes}{itemType} = $gearBaseType{"$gearbase"};
                $item{attributes}{baseItemName} = $gearbase;
                last;
              }
            }
          }
       } elsif ($data->{frameType} == 4) {
          $item{attributes}{baseItemName} = $item{info}{fullName};
          $item{attributes}{itemType} = "Gem";
          $item{attributes}{baseItemType} = "Gem";
        } elsif ($data->{frameType} == 6) {
          $item{attributes}{itemType} = "Card";
          $item{attributes}{baseItemType} = "Card";
          $item{attributes}{baseItemName} = $item{info}{fullName};
        } elsif ($data->{frameType} == 5) {
          $item{attributes}{itemType} = "Currency";
          $item{attributes}{baseItemType} = "Currency";
          $item{attributes}{baseItemName} = $item{info}{fullName};
        } elsif ($data->{frameType} == 7) {
          $item{attributes}{itemType} = "Quest Item";
          $item{attributes}{baseItemType} = "Quest Item";
          $item{attributes}{baseItemName} = $item{info}{fullName};
        } elsif ($data->{frameType} == 8) {
          $item{attributes}{itemType} = "Prophecy";
          $item{attributes}{baseItemType} = "Prophecy";
          $item{attributes}{baseItemName} = $item{info}{fullName};
        }
      
        # If we didn't match the $localItemBaseName during the iteration above because
        # the frameType wasn't clear, let's match it now
        unless ($item{attributes}{baseItemName}) {
          &d("UNIDENTIFIED BASE ITEM NAME: $item{info}{fullName} : $data->{typeLine}\n");
          foreach my $gearbase (@gearBaseTypeArray) {
            if ($data->{typeLine} =~ /\b$gearbase\b/) {
              $item{attributes}{baseItemName} = $gearbase;
              last;
            }
          }
          # Fall back on the typeLine if all else fails
          $item{attributes}{baseItemName} = $data->{typeLine} unless ($item{attributes}{baseItemName});
        }
      
        if ($item{attributes}{itemType} =~ /^(Bow|Axe|Sword|Dagger|Mace|Staff|Claw|Sceptre|Wand|Fishing Rod)$/) {
          $item{attributes}{baseItemType} = "Weapon";
        } elsif ($item{attributes}{itemType} =~ /^(Helmet|Gloves|Boots|Body|Shield|Quiver)$/) {
          $item{attributes}{baseItemType} = "Armour";
        } elsif ($item{attributes}{itemType} =~ /^(Amulet|Belt|Ring)$/) {
          $item{attributes}{baseItemType} = "Jewelry";
        } else {
          $item{attributes}{baseItemType} = $item{attributes}{itemType};
        }
      
        unless ($item{attributes}{baseItemType}) {
          &d("WARNING UNIDENTIFIED BASE ITEM TYPE: $item{info}{fullName} : $data->{typeLine} is!\n");
          next;
        }
      
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
      
        # ========== ITEM REQUIREMENTS ==================================
      
        # I'm not a JSON expert, but the way the JSON is laid out here makes it very difficult to reference.
        # For some sections, like requirements, they're using arrays of hashes with nested arrays, so
        # de-referencing these efficiently can be very tricky. Basically we get to do some weird
        # iteration through stuff to de-reference it.
      
        my $p = "0";
        # Find each hash in the array under requirements and do stuff with it
        foreach my $pval (@{$data->{'requirements'}}) {
          if ($data->{requirements}->[$p]->{name}) {
            # Set the local requirement name, which is a fixed value in the hash
            my $requirement = $data->{requirements}->[$p]->{name};
      
            # Standardize some of the attributes stuff - for some reason, some items have Int and other have Intelligence, etc.
            $requirement = "Int" if ($requirement eq "Intelligence");
            $requirement = "Str" if ($requirement eq "Strength");
            $requirement = "Dex" if ($requirement eq "Dexterity");
            # Flatted the name to first uppercase only
            $requirement = ucfirst($requirement);
      
            # At the time of writing, the actual value is always the first element in the first nested array in the JSON
            # data. I don't know why it's laid out like this, i.e.
            # requirements : [ { values : [ [ "20", 0 ] ] } ]
            my $value = $data->{requirements}->[$p]->{values}->[0]->[0];
      
            # Add this information to the hash. We use += to ensure it's added as a number and avoid any weird situations
            # where an item has two requirements of the same type causing the value to get lost
            $item{requirements}{$requirement} += $value;
          }
          $p++;
        }
      
        # ======== PROPERTIES ================================
      
        # Time to do the same for properties, which is also laid out kinda weird
        # Note, a LOT of calculations happen here in properties, it can get a bit complicated
      
        my $p = "0";
        foreach my $pval ( @{$data->{'properties'}} ) {
      #    last unless ($p); # This isn't strictly necessary, but this loop can hang due to corrupted JSON otherwise
          if ($data->{properties}->[$p]->{name}) {
            my $property = $data->{properties}->[$p]->{name};
            my $value = $data->{properties}->[$p]->{values}->[0]->[0];


            # Remove percentages from values
            $value =~ s/\%//o;

            # Remove " sec" from cast times and cooldown times for gems
            if (($item{attributes}{baseItemType} eq "Gem") && ($value =~ /^\d+(\.\d{1,2}) sec/)) {
              $value =~ s/ sec.*$//o;
            }

            # If the property contains (MAX) (for gems) just remove that portion so it's numeric
            if ($value =~ / \(MAX\)/i) {
              $value =~ s/ \(MAX\)//ig;
            }
            # Clean up some flask properties
            if ($property =~ /\%\d/) {
              $property =~ s/\%0/#/g;
              $property =~ s/\%1/#/g;
            }

            # Check to see if this is a boolean
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
      
      
            # Detection for elemental damage types
            # see https://github.com/trackpete/exiletools-indexer/issues/62
            if ($property eq "Elemental Damage") {
              &CreateElementalDamageTypeHash unless (%elementalDamageType);
              my $elep = "0";
              foreach my $eleparr ( @{$data->{properties}->[$p]->{values}} ) {
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
              $item{properties}{$item{attributes}{baseItemType}}{$property}{x} += $data->{properties}->[$p]->{values}->[0]->[0];
              $item{properties}{$item{attributes}{baseItemType}}{$property}{y} += $data->{properties}->[$p]->{values}->[1]->[0];
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
              if (($value =~ /^\d+$/) || ($value =~ /^\d+(\.\d{1,2})?$/)) {                                                   
                $item{properties}{$item{attributes}{baseItemType}}{$property} += $value;
              } else {                              
                $item{properties}{$item{attributes}{baseItemType}}{$property} = $value;
              }                                                                                                                                                      
            }
          } elsif (($data->{properties}->[$p]->{values}->[0]->[0]) && ($data->{properties}->[$p]->{values}->[0]->[1])) {
            my $property = $data->{properties}->[$p]->{values}->[0]->[0];
            my $value = $data->{properties}->[$p]->{values}->[0]->[1];
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
        if ($item{attributes}{baseItemType} eq "Gem" && $data{additionalProperties}->[0]->{values}->[0]->[0] =~ /^\d+\/\d+$/) {
          my ($xpCurrent, $xpGoal) = split(/\//, $data{additionalProperties}->[0]->{values}->[0]->[0]);
          $item{properties}{$item{attributes}{baseItemType}}{Experience}{Current} += $xpCurrent;
          $item{properties}{$item{attributes}{baseItemType}}{Experience}{NextLevel} += $xpGoal;
          $item{properties}{$item{attributes}{baseItemType}}{Experience}{PercentLeveled} += int($xpCurrent / $xpGoal * 100);
        }
      
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
      
        # If there is a properties.Weapon.type set, extract the first one and set attributes.weaponType
        if ($item{properties} && $item{properties}{Weapon}) {
          my @types = keys(%{$item{properties}{Weapon}{type}});
          $item{attributes}{weaponType} = $types[0];
        }
      
        # ======= SOCKETS SOCKETS SOCKETS ==========================
        if ($data->{sockets}->[0]->{attr}) {
          # Kinda hacky
          # https://github.com/trackpete/exiletools-indexer/issues/106
          foreach my $socket (@{$data->{sockets}}) {
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
          my %sockets;
          my $socketcount;
          my $allSockets;
          my $allSocketsGGG;

          for (my $socketprop=0;$socketprop <= 10;$socketprop++) {
            my $group = $data->{sockets}->[$socketprop]->{group};
            $sockets{group}{$group} .= $data->{sockets}->[$socketprop]->{attr} if ($data->{sockets}->[$socketprop]->{attr})
          }

          foreach my $group (sort keys(%{$sockets{group}})) {
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
          $item{sockets}{largestLinkGroup} = $sockets{maxLinks};
          $item{sockets}{socketCount} = $sockets{count};
          $item{sockets}{allSockets} = $allSockets;
          $item{sockets}{allSocketsSorted} = $sorted;
          $item{sockets}{allSocketsGGG} = $allSocketsGGG;

          foreach $sortGroup (keys(%sortGroup)) {
            $item{sockets}{sortedLinkGroup}{$sortGroup} = $sortGroup{$sortGroup};
          }
#          print Dumper($item{sockets});
        }
      
        # ======= MODS MODS MODS =====================================
        # This section parses out the various mods. This is kinda expensive.
      
      
        # Enchantments are a little interesting. For now, we're going to assume they are FIXED
        # value mods and set them as boolean true instead of variable range mods.
        # If this turns out to be wrong, we should be able to simply call parseExtendedMods for
        # the enchantMods line
        foreach my $mod (@{$data->{enchantMods}}) {
          $item{attributes}{enchantModsCount}++;
          $mod =~ s/\.//g;
          $mod =~ s/\n/ /g;
          $mod =~ s/\\n/ /g;
          $item{enchantMods}{"$mod"} = \1;
        } 
      
        &parseExtendedMods("implicitMods","implicit",$data->{implicitMods}) if ($data->{implicitMods});
        &parseExtendedMods("explicitMods","explicit",$data->{explicitMods}) if ($data->{explicitMods});
        &parseExtendedMods("craftedMods","crafted",$data->{craftedMods}) if ($data->{craftedMods});
        &parseExtendedMods("cosmeticMods","cosmetic",$data->{cosmeticMods}) if ($data->{cosmeticMods});
      
        # Add a PseudoMod count for total resists
        if ($item{modsPseudo}) {
          foreach $elekey (keys (%{$item{modsPseudo}})) {
            $item{modsPseudo}{"# of Elemental Resistances"}++ if ($elekey =~ /(Cold|Fire|Lightning)/);
            $item{modsPseudo}{"# of Resistances"}++ if ($elekey =~ /(Cold|Fire|Lightning|Chaos)/);
          }
        }

        # ====== Q20 CALCULATIONS ===========================
        # This section will calculate some pseudo properties, it must be AFTER both
        # properties and mods determination

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
          # only process items with more than 0 physical dps
          if ($item{properties}{Weapon}{"Physical DPS"} > 0) {
            # If this is already 20, we don't have to change anything
            if ($item{properties}{Quality} == 20) {
              $item{propertiesPseudo}{Weapon}{estimatedQ20}{"Physical DPS"} = ($item{properties}{Weapon}{"Physical DPS"} * 1);
            } else {
              # Crap, we have to try to estimate the Q20 values
              # Does this item have an increased mod?
              if ($item{modsTotal}{"#% increased Physical Damage"} > 0) {
                $item{propertiesPseudo}{Weapon}{estimatedQ20}{"Physical DPS"} = (int($item{properties}{Weapon}{"Physical DPS"} / (1 + ($item{modsTotal}{"#% increased Physical Damage"} + $item{properties}{Quality}) / 100) * (1 + (($item{modsTotal}{"#% increased Physical Damage"} + 20) / 100))) * 1);
              } else {
                $item{propertiesPseudo}{Weapon}{estimatedQ20}{"Physical DPS"} = (int(($item{properties}{Weapon}{"Physical DPS"} / (1 + $item{properties}{Quality} / 100)) * 1.20) * 1);
              }
            }
            # Update Total DPS per Issue #114
            if ($item{properties}{Weapon}{"Elemental DPS"}) {
              $item{propertiesPseudo}{Weapon}{estimatedQ20}{"Total DPS"} += $item{propertiesPseudo}{Weapon}{estimatedQ20}{"Physical DPS"} + $item{properties}{Weapon}{"Elemental DPS"};
            } else {
              $item{propertiesPseudo}{Weapon}{estimatedQ20}{"Total DPS"} += $item{propertiesPseudo}{Weapon}{estimatedQ20}{"Physical DPS"};
            }
          }
        }
      
        # ===== MISC MISC MISC ===============================
        # Anything we need to clean up or finish adding before this item is considered fully formatted
      
        # Create a default message
        if ($item{shop}{amount} && $item{shop}{currency}) {
          if ($item{attributes}{baseItemType} eq "Gem") {
            if ($item{properties}{Quality}) {
              $item{shop}{defaultMessage} = "\@$item{shop}{lastCharacterName} I would like to buy your level $item{properties}{Gem}{Level} $item{properties}{Quality}% $item{info}{fullName} listed for $item{shop}{amount} $item{shop}{currency} (League:$item{attributes}{league}, Stash Tab:\"$item{shop}{stash}{stashName}\" [x$item{shop}{stash}{xLocation},y$item{shop}{stash}{yLocation}])";
            } else {
              $item{shop}{defaultMessage} = "\@$item{shop}{lastCharacterName} I would like to buy your level $item{properties}{Gem}{Level} $item{info}{fullName} listed for $item{shop}{amount} $item{shop}{currency} (League:$item{attributes}{league}, Stash Tab:\"$item{shop}{stash}{stashName}\" [x$item{shop}{stash}{xLocation},y$item{shop}{stash}{yLocation}])";
            }
          } else {
            $item{shop}{defaultMessage} = "\@$item{shop}{lastCharacterName} I would like to buy your $item{info}{fullName} listed for $item{shop}{amount} $item{shop}{currency} (League:$item{attributes}{league}, Stash Tab:\"$item{shop}{stash}{stashName}\" [x$item{shop}{stash}{xLocation},y$item{shop}{stash}{yLocation}])";
          }
        }


# === END Item Processing Code Chunk (this tag is used to extract this into other subroutines)

        my $itemStatus;
        if ($itemInES->{uuid}) {
          # If the current note and the stash name are the same, then the item wasn't modified
          if (($itemInES->{shop}->{note} eq $item{shop}{note}) && ($itemInES->{shop}->{stash}->{stashName} eq $item{shop}{stash}{stashName})) {  
            $item{shop}{modified} = $itemInES->{shop}->{modified};
            $itemStatus = "Unchanged";
            &sv("i  Unchanged: $item{shop}{sellerAccount} | $item{info}{fullName} | $item{uuid} | $item{shop}{amount} $item{shop}{currency}\n");
          } else {
            $item{shop}{modified} = time() * 1000;
            $itemStatus = "Modified";
            &sv("i  Modified: $item{shop}{sellerAccount} | $item{info}{fullName} | $item{uuid} | $item{shop}{amount} $item{shop}{currency}\n");
          }
          $item{shop}{updated} = time() * 1000;
          $item{shop}{added} = $itemInES->{shop}->{added};
          $item{shop}{shelfLife} += (($item{shop}{updated} - $item{shop}{added}) / 1000);
        } else {
          # It's new!
          $item{shop}{modified} = time() * 1000;
          $item{shop}{updated} = time() * 1000;
          $item{shop}{added} = time() * 1000;
          $itemStatus = "Added";
          &sv("i  Added: $item{shop}{sellerAccount} | $item{info}{fullName} | $item{uuid} | $item{shop}{amount} $item{shop}{currency}\n");
        }
        # === END JSON FORMAT PARSING =====

        # Prepare the resulting data to go to the processed topic
        # my $jsonout = JSON::XS->new->utf8->pretty->encode(\%item);
        if ($args{debugjson}) {
          my $prettyout = JSON::XS->new->utf8->pretty->encode(\%item);
          if ($args{debugjson} eq "all") {
            print "========================================\n$prettyout\n=============================================\n";
          } elsif ($item{attributes}{baseItemType} eq $args{debugjson}) {
            print "========================================\n$prettyout\n=============================================\n";
          }
        } else { 
          my $jsonout = JSON::XS->new->utf8->encode(\%item);
          $itemBulk->index({ id => "$item{uuid}", source => "$jsonout"});
          # Add modified and added items to Kafka Processed queue
          if (($itemStatus eq "Modified") || ($itemStatus eq "Added")) {
            push @kafkaMessages, $jsonout;
            &sv("$item{uuid} was Added or Modified, adding to Processed Kafka queue\n");
          }
        }

        $localChangeStats{"$itemStatus"}++;                                        
        $itemStats{"$itemStatus"}++;                                               
      }
      $totalItemCount += $itemCount;

      # Compare the current stash information to the previous stash information to determine what has been removed
      foreach $scanItem (@{$currentStashData->{hits}->{hits}}) {
        if ($scanItem->{_source}->{uuid}) {
          my $item = $scanItem->{_source};
          $item->{shop}->{modified} = time() * 1000;
          $item->{shop}->{updated} = time() * 1000;
          $item->{shop}->{shelfLife} += (($item->{shop}->{updated} - $item->{shop}->{added}) / 1000);
          $item->{shop}->{verified} = "GONE";
          if ($args{debugjson} == 1) {
            my $prettyout = JSON::XS->new->utf8->pretty->encode(\%item);
            print "========================================\n$prettyout\n=============================================\n";
          } else { 
            my $jsonout = JSON::XS->new->utf8->encode(\%{$item});
            $itemBulk->index({ id => "$item->{uuid}", source => "$jsonout"});
            # Add GONE items to kafka processed queue for notifications as well
            &sv("$item->{uuid} is GONE, adding to processed kafka queue\n");
            push @kafkaMessages, $jsonout;
          }
          &sv("i  Gone: $item->{shop}->{sellerAccount} | $item->{info}->{fullName} | $item->{uuid} | $item->{shop}->{amount} $item->{shop}->{currency}\n");
        }
      }

      # Send to kafka
      my $kpr0 = [Time::HiRes::gettimeofday];
      $producer->send(
        $conf{kafkaTopicNameProcessed},
        0,
        [ @kafkaMessages ]
      );
      my $kprInterval = Time::HiRes::tv_interval ( $kpr0, [Time::HiRes::gettimeofday]);
      $totalKafkaProductionTime += $kprInterval;

      if ($processedCount % 200 == 0) {
        $interval = Time::HiRes::tv_interval ( $tk1, [Time::HiRes::gettimeofday]);
        &d("* Consumed $processedCount stashtabs ($totalItemCount items) in ".sprintf("%.2f", $interval)."s (".sprintf("%.2f", $processedCount / $interval)." tab/s, ".sprintf("%.2f", $totalItemCount / $interval)." items/s) (".sprintf("%.4f", $totalKafkaProductionTime)."s kafka production time).\n");
        open(my $OFFSETLOG, ">", $offsetLog) || die "FATAL: Unable to open $offsetLog - $!\n";
        print $OFFSETLOG $message->next_offset;
        close($OFFSETLOG);
      }
      $finalOffset = $message->next_offset;
    } else {
        print 'error      : ', $message->error;
    }
    $itemBulk->flush;
    open(my $OFFSETLOG, ">", $offsetLog) || die "FATAL: Unable to open $offsetLog - $!\n";
    print $OFFSETLOG $message->next_offset;
    close($OFFSETLOG);
    $lastOffset = $message->next_offset;
}



$interval = Time::HiRes::tv_interval ( $tk1, [Time::HiRes::gettimeofday]);
&d("* Consumed $processedCount stashtabs ($totalItemCount items) in ".sprintf("%.2f", $interval)."s (".sprintf("%.2f", $processedCount / $interval)." tab/s, ".sprintf("%.2f", $totalItemCount / $interval)." items/s) (".sprintf("%.4f", $totalKafkaProductionTime)."s kafka production time).\n");

}
# END DAEMON LOOP












 
# cleaning up
undef $consumer;
undef $producer;
$connection->close;
undef $connection;


sub connectElastic {

  # Nail up the Elastic Search connections
  our $e = Search::Elasticsearch->new(                                             
    cxn_pool => 'Sniff',
    cxn => 'Hijk',
    nodes =>  [
      "$conf{esHost}:9200"
    ],
    # enable this for debug but BE CAREFUL it will create huge log files super fast
  #   trace_to => ['File','/tmp/eslog.txt'],

    # Huge request timeout for bulk indexing
    request_timeout => 180
  );

  our $itemBulk = $e->bulk_helper(
    index => "$conf{esItemIndex}",
    max_count => '25000',
    max_time => '20',
    max_size => 0,
    type => "$conf{esItemType}",
  );
}
