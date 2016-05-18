#!/usr/bin/perl

sub parseClipboardText {
  local $text = $_[0];

  # Create a local item information hash
  local %i;

  # Fix set idiocy
  $text =~ s/<<set:(\S+?)>>//g;

  # Remove Diacritics
  $text = unidecode($text);

  &d("Submitted Item Data:\n<--\n$text\n-->\n\n");

  # Begin by extracting some basic item information

  if ($text =~ /^Unidentified$/m) {
    $i{attributes}{identified} = \0;
  } else {
    $i{attributes}{identified} = \1;
  }

  $i{attributes}{corrupted} = \1 if ($text =~ /^Corrupted$/m);

  # Split the text into chunks for additional processing
  my @itemChunks = split(/--------\n/, $text);

  # Analyze the first chunk to determine the rarity and item name
  my @chunk = split(/\n/, $itemChunks[0]);
  my $rarityLine = shift(@chunk);
  $rarityLine =~ /^Rarity: (.*?)$/;
  $i{attributes}{rarity} = $1;

  $i{info}{fullName} = join(" ", @chunk);

  # Some of these are broken out into other subroutines for legibility
  # Set the item type, equip type, base item type for the item
  &clipboardTextSetType;

  # If the item has sockets, parse 'em
  &clipboardTextSetSockets("$1") if ($text =~ /^Sockets: (.*?)$/m);

  # If the item is armour, pull known armour properties
  &clipboardTextSetPropertiesArmour if ($i{attributes}{baseItemType} eq "Armour");





  my $debugItemHash = Dumper(%i);
  &d("Item Hash:\n<--\n$debugItemHash\n-->\n");
}

sub clipboardTextSetPropertiesArmour {




}

sub clipboardTextSetSockets {
  my @sockets = split(/ /, $_[0]);
  my $largestLinkGroup;
  my $socketCount;
  foreach $linkGroup (@sockets) {
    $linkGroup =~ s/-//g;
    $largestLinkGroup = length($linkGroup) if (length($linkGroup) > $largestLinkGroup); 
    $socketCount = $socketCount + length($linkGroup);
  }
  $i{sockets}{largestLinkGroup} += $largestLinkGroup;
  $i{sockets}{socketCount} += $socketCount;




}



sub clipboardTextSetType {
  if ($text =~ /^Map Tier:/m) {
    $i{attributes}{baseItemType} = "Map";
    $i{attributes}{itemType} = "Map";
    $i{attributes}{equipType} = "Map";
  } elsif ($text =~ /^Right click to drink/m) {
    $i{attributes}{baseItemType} = "Flask";
    $i{attributes}{itemType} = "Flask";
    $i{attributes}{equipType} = "Flask";
  } elsif ($i{attributes}{rarity} eq "Gem") {
    $i{attributes}{baseItemType} = "Gem";
    $i{attributes}{itemType} = "Gem";
    $i{attributes}{equipType} = "Gem";
  } elsif ($i{attributes}{rarity} eq "Currency") {
    $i{attributes}{baseItemType} = "Currency";
    $i{attributes}{itemType} = "Currency";
    $i{attributes}{equipType} = "Currency";
  } else {
    my $localBaseItemType;
    my $localItemType;
    my $localEquipType;

    foreach my $gearbase (keys(%gearBaseType)) {
      if ($i{info}{fullName} =~ /\b$gearbase\b/) {
        $localItemType = $gearBaseType{"$gearbase"};
        last;
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

    unless ($localItemType) {
      if ($i{info}{fullName} =~ /\bTalisman\b/) {
        $localItemType = "Amulet";
        $localBaseItemType = "Jewelry";
        $localEquipType = "Talisman";
      } elsif (($text =~ /^Stack Size/m) && ($i{attributes}{rarity} eq "Normal")) {
        $localItemType = "Card";
        $localBaseItemType = "Card";
        $localEquipType = "Card";
      } else {
        $localItemType = "Unknown";
      }
    }

    if (($text =~ /^One Handed/m) || ($text =~ /^(Claw|Dagger)$/m)) {
      $localEquipType = "One Handed Melee Weapon";
    } elsif (($text =~ /^Two Handed/m) || ($text =~ /^Staff$/m)) {
      $localEquipType = "Two Handed Melee Weapon";
    } elsif ($text =~ /^Wand$/m) {
      $localEquipType = "One Handed Projectile Weapon";
    }
    $i{attributes}{baseItemType} = $localBaseItemType;
    $i{attributes}{itemType} = $localItemType;
    $localEquipType = $localItemType unless ($localEquipType);
    $i{attributes}{equipType} = $localEquipType;
  }
}


return true;
