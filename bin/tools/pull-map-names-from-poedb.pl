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
our @mapNames;

&ProcessURL("$baseurl\?cn=Map");

if ($ARGV[0] eq "json") {
  use JSON::XS;
  my $jsonout = JSON::XS->new->utf8->pretty->encode(\@mapNames);
  print $jsonout."\n";
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
#  $content =~ s/\n//g;
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
    if ($line =~ /<a href=\'item\.php\?n=(\S+?)\'>(.*?)<\/a>/) {
      my $name = $2;
      print "$name\n" unless ($ARGV[0] eq "json");
      push @mapNames, $name;
    }
  }
}
