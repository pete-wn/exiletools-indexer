#!/usr/bin/perl

# IMPORTANT NOTE:
# This subroutine used to handle ALL of the JSON processing, however the
# main part of this was moved into the processing core program for performance
# reasons.

require('subs/sub.uniqueItemInfoHash.pl');

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
  # mod array
  my $mods = $_[2];
#  return unless (($modTypeJSON) && ($modType));

  foreach my $modLine ( @{$mods} ) {
    # Remove any apostrophes or periods
    $modLine =~ s/\'//g;
    $modLine =~ s/\. //g;
    $modLine =~ s/\n/ /g;
    $modLine =~ s/\\n/ /g;

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
      } elsif (($modLine =~ /^(With at least .*?)$/) || ($modLine =~ /^(With .* Allocated.*?)$/)) {
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

