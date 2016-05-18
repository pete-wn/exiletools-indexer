#!/usr/bin/perl

# This program uses the data mined information from the ggpk file posted
# at poedb.tw to create the %gearBaseType hash of all known
# base item names
#
# It may break at any time if there are changes to the poedb.tw format
#
# The output of this can be copy/pasted into subs/sub.itemBaseTypes.pl to
# update that hash

use LWP::UserAgent;
use HTML::Tree;
use Encode;
use Data::Dumper;

# Grab the list of item types from:
$baseurl = "http://poedb.tw/us/item.php";

# Hash of types to convert - the key is the poedb title, the value is the baseItemType we will use
$h{"Claws"} = "Claw";
$h{"Daggers"} = "Dagger";
$h{"Wands"} = "Wand";
$h{"One Hand Swords"} = "Sword";
$h{"Thrusting One Hand Swords"} = "Sword";
$h{"One Hand Axes"} = "Axe";
$h{"One Hand Maces"} = "Mace";
$h{"Sceptres"} = "Sceptre";
$h{"Bows"} = "Bow";
$h{"Staves"} = "Staff";
$h{"Two Hand Swords"} = "Sword";
$h{"Two Hand Axes"} = "Axe";
$h{"Two Hand Maces"} = "Mace";
$h{"Fishing Rods"} = "Fishing Rod";

$h{"Gloves"} = "Gloves";
$h{"Boots"} = "Boots";
$h{"Body Armours"} = "Body";
$h{"Helmets"} = "Helmet";
$h{"Shields"} = "Shield";

$h{"Amulets"} = "Amulet";
$h{"Rings"} = "Ring";
$h{"Quivers"} = "Quiver";
$h{"Belts"} = "Belt";
$h{"Jewel"} = "Jewel";

$h{"Life Flasks"} = "Flask";
$h{"Mana Flasks"} = "Flask";
$h{"Hybrid Flasks"} = "Flask";
$h{"Utility Flasks"} = "Flask";
$h{"Maps"} = "Map";
$h{"Map Fragments"} = "Vaal Fragment";

$h{"Divination Card"} = "Card";


my @content = split(/\n/, GetURL("$baseurl"));
foreach $line (@content) {
  if ($line =~ /<li><a  href=\'item.php\?cn=(\S+)\'>(.*?)<\/a>/) {
    my $endurl = $1;
    my $dbtype = $2;
    next unless ($h{"$dbtype"});
#    print "$baseurl\?c=$endurl $h{$dbtype}\n";
    &ProcessURL("$baseurl\?cn=$endurl", $h{"$dbtype"});
  }

}

exit;

print Dumper(%h);

exit;
# == Subroutines =====================

sub GetURL {

  my $url = $_[0];

  my $ua = LWP::UserAgent->new;
  my $can_accept = HTTP::Message::decodable;
  my $response = $ua->get("$url",'Accept-Encoding' => $can_accept);
  my $content = $response->decoded_content;
  #my $htmltree = HTML::Tree->new();
  #$htmltree->parse($content);
  #my $clean = $htmltree->as_HTML;

  return($content);
}

sub ProcessURL {
  my $content = &GetURL("$_[0]");
  my $type = $_[1];
  my @content = split(/<tr>/, $content);
  foreach $line (@content) {
    if ($line =~ /<td><a href=\'item.php\?n=(.*?)\'>(.*?)<\/a>/) {
      print "\$gearBaseType\{\"$2\"\} = \"$type\";\n";
    }
  }
}
