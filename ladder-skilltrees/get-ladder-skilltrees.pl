#!/usr/bin/perl

# This script will fetch the ladder for a league then each of the skilltrees for
# each character on this league. 
#
# See https://github.com/trackpete/exiletools-indexer/issues/90 for development
# status.

$|=1;

use LWP::UserAgent;
use Data::Dumper;
use JSON;
use JSON::XS;
use Encode;
use utf8::all;
use Time::HiRes qw(usleep);
use Search::Elasticsearch;

chdir("..");
require("subs/all.subroutines.pl");

# For deployment to other servers, this should be changed to point to
# http://api.exiletools.com/ladder
$ladderApiURL = 'http://localhost/ladder?showAll=1&format=perl';

# The official pathofexile.com URL for getting character skilltree data
$skilltreeURL = 'https://www.pathofexile.com/character-window/get-passive-skills?reqData=0';

# == Initial Startup
&StartProcess;

# Create the %nodeHash lookup table for node information
&createNodeHash;

# Set global rundate variable
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
our $runDate = ($year + 1900).sprintf("%02d", ($mon + 1)).sprintf("%02d", $mday);

if ($args{league}) {
  &fetchSkilltrees("$args{league}");
} else {
  &d("ERROR: You must specify a league with -league!\n");
  &ExitProcess;
}

# == Exit cleanly
&ExitProcess;

sub fetchSkilltrees {
  local $league = $_[0];

  local $publicCount = 0;
  local $totalCount = 0;

  &d("Fetching list of characters on ladder in $league\n");

  # Set up Elasticsearch Connection
  my $e = Search::Elasticsearch->new(
    cxn_pool => 'Sniff',
    nodes =>  [
      "$conf{esHost}:9200",
      "$conf{esHost2}:9200"
    ],
    # enable this for debug but BE CAREFUL it will create huge log files super fast
    # trace_to => ['File','/tmp/eslog.txt'],

    # Huge request timeout for bulk indexing
    request_timeout => 300
  );

  die "some error?"  unless ($e);
  
  our $bulk = $e->bulk_helper(
    index => "skilltree",
    max_count => '100',
    max_size => '0',
    type => "character",
  );

  # Create a user agent
  our $ua = LWP::UserAgent->new;
  # Make sure it accepts gzip
  our $can_accept = HTTP::Message::decodable;

  # Fetch data from the ladder
  my $response = $ua->get("$ladderApiURL&league=$league",'Accept-Encoding' => $can_accept);

  # Decode the returned data as a perl hash
  my %ladderData = %{eval $response->decoded_content};

  # Circuit breaker
  $count = 0;

  foreach $char (%ladderData) {
    if ($ladderData{$char}{rank} && $ladderData{$char}{accountName} && $ladderData{$char}{charName}) {
      $count++;
#      last if ($count > 10000);
      if ($count % 500 == 0) {
        &d("$count characters processed\n");
      }
      &fetchTreeForChar("$ladderData{$char}{accountName}","$ladderData{$char}{charName}","$ladderData{$char}{rank}","$ladderData{$char}{dead}","$ladderData{$char}{level}","$ladderData{$char}{class}");
      usleep(5000);
    }
  }
  &sv("Bulk flushing data\n");
  $bulk->flush;

  &d("Total Characters Checked: $totalCount\n");
  &d("Total Characters Public: $publicCount\n");
}

sub fetchTreeForChar {
  my $accountName = $_[0];
  my $character = $_[1];
  my $rank = $_[2];
  my $dead = $_[3];
  my $level = $_[4];
  my $class = $_[5];

  $totalCount++;

  # Create a hash for the parsed tree data to be stored in
  my %treeData;
  $treeData{info}{accountName} = $accountName;
  $treeData{info}{accountNameTokenized} = $accountName;
  $treeData{info}{characterTokenized} = $character;
  $treeData{info}{character} = $character;
  $treeData{info}{rank} += $rank;
  $treeData{info}{league} = $league;
  $treeData{info}{runDate} = $runDate;
  $treeData{info}{dead} = $dead;
  $treeData{info}{level} = $level;
  $treeData{info}{class} = $class;

  # Fetch skilltree from pathofexile.com
  my $response = $ua->get("$skilltreeURL&accountName=$accountName&character=$character",'Accept-Encoding' => $can_accept);
 
  # Decode response
  my $content = $response->decoded_content;

  if ($content eq "false") {
    # If the content is false then this character is private or deleted, ignore it
    &d("$accountName $character $rank is private!\n");
    $treeData{info}{private} = \1;
    # convert treeData to JSON
    my $jsonOut = JSON::XS->new->utf8->encode(\%treeData);
    # Prepare for bulk adding to ES
    $bulk->index({ id => "$runDate-$league-$rank", source => "$jsonOut"});

  } elsif ($content =~ /DOCTYPE html/) {
    &d("$accountName $character $rank is probably utf8 or something, got HTML response.\n");
  } else {
    &d("Got data for $accountName $character $rank\n");
    $publicCount++;
    $treeData{info}{private} = \0;

    # encode the JSON data into something perl can reference 
    my $data = decode_json(encode("utf8", $content));

    # Parse the jewel_slots data to keep track of jewel nodes
    my %jewelNodes;
    foreach $slotHash (@{$data->{jewel_slots}}) {
      my $jewelHash = $slotHash->{passiveSkill}->{hash};
      $jewelNodes{$jewelHash} = \1;
    }

    # Parse the hash array to see what nodes have been selected
    my $skillPointCount = 0;
    my $jewelPointCount = 0;
    foreach $id (@{$data->{hashes}}) {
      $skillPointCount++;
      my %nHash;
      $nHash{node} += $id ;
      $nHash{chosen} = \1;
      $nHash{nodename} = $nodeHash{$id}{name};
      $nHash{isNoteable} = $nodeHash{$id}{isNoteable};
      $nHash{isKeystone} = $nodeHash{$id}{isKeystone};
      $nHash{icon} = $nodeHash{$id}{icon};

      push @{$treeData{skillNodes}}, \%nHash;

      # Calculate the stats from the node
      foreach $bonus (@{$nodeHash{$id}{bonuses}}) {
        # Rudimentary matching of the bonus
        if ($bonus =~ /^(.*?)+(\d+(\.\d{1,2})?)(.*?)$/) {
          $treeData{nodeBonusesTotal}{"$1+#$4"} += $2;
          $treeData{allBonusesTotal}{"$1+#$4"} += $2;
        } elsif ($bonus =~ /^(.*?)(\d+(\.\d{1,2})?)\%(.*?)$/) {
          $treeData{nodeBonusesTotal}{"$1#%$4"} += $2;
          $treeData{allBonusesTotal}{"$1#%$4"} += $2;
        } else {
          $treeData{nodeBonusesTotal}{"$bonus"} = \1;
          $treeData{allBonusesTotal}{"$bonus"} = \1;
        }
      }

      # If this is a jewel node, increment the jewel count
      $jewelPointCount++ if ($jewelNodes{$id});
    }
    $treeData{info}{skillPointsUsed} += $skillPointCount;
    $treeData{info}{jewelSlots} += $jewelPointCount;
    &sv(" * used $skillPointCount skill points | $jewelPointCount Jewel Slots\n");

    # Perform an abbreviated analysis and conversion of the jewels
    # We're only going to look for:
    #
    #   name + typeLine (remove Set crap)
    #   frameType
    #   frameType -> x (then convert this to a hash node)
    #   implicitMods
    #   explicitMods
    #
    # I don't think anything else matters
   
    foreach $jewel (@{$data->{items}}) {
      my %jewelHash;
      $jewelHash{name} = $jewel->{name}." ".$jewel->{typeLine};
      # Remove set crap
      $jewelHash{name} =~ s/<<set:(\S+?)>>//g;
      # Remove any trailing or leading spaces
      $jewelHash{name} =~ s/(^\s+|\s+$)//g;
      $jewelHash{frameType} = $jewel->{frameType};
      $jewelHash{slotArrayLocation} = $jewel->{x};
      $jewelHash{node} += $data->{jewel_slots}->[$jewel->{x}]->{passiveSkill}->{hash};

      # Very rudimentary mod parsings, search for +# or #% otherwise set a boolean true
      foreach $mod (@{$jewel->{explicitMods}}) {
        # deal with that jewel that does #-#
        if ($mod =~ /^+(\d+-\d+) (.*?)$/) {
          my %modHash;
          $modHash{"$2"} = "$1";
          $treeData{jewelModsTotal}{"$2"} = $1;
          $treeData{allBonusesTotal}{"$2"} += $1;
          push @{$jewelHash{explicitMods}}, \%modHash;
        } elsif ($mod =~ /^(.*?)+(\d+(\.\d{1,2})?)(.*?)$/) {
          my %modHash;
          $modHash{"$1+#$4"} += $2;
          $treeData{jewelModsTotal}{"$1+#$4"} += $2;
          $treeData{allBonusesTotal}{"$1+#$4"} += $2;
          push @{$jewelHash{explicitMods}}, \%modHash;
        } elsif ($mod =~ /^(.*?)(\d+(\.\d{1,2})?)\%(.*?)$/) {
          my %modHash;
          $modHash{"$1#%$4"} += $2;
          $treeData{jewelModsTotal}{"$1#%$4"} += $2;
          $treeData{allBonusesTotal}{"$1#%$4"} += $2;
          push @{$jewelHash{explicitMods}}, \%modHash;
        } else {
          my %modHash;
          $modHash{"$mod"} = \1;
          $treeData{jewelModsTotal}{"$mod"} = \1;
          $treeData{allBonusesTotal}{"$mod"} = \1;
          push @{$jewelHash{explicitMods}}, \%modHash;
        }
      }

      # Repeat for implicit mods - yes this is lazy copy pasting the same code
      foreach $mod (@{$jewel->{implicitMods}}) {
        if ($mod =~ /^(.*?)+(\d+(\.\d{1,2})?)(.*?)$/) {
          my %modHash;
          $modHash{"$1+#$4"} += $2;
          $treeData{jewelModsTotal}{"$1+#$4"} += $2;
          push @{$jewelHash{implicitMods}}, \%modHash;
        } elsif ($mod =~ /^(.*?)(\d+(\.\d{1,2})?)\%(.*?)$/) {
          my %modHash;
          $modHash{"$1#%$4"} += $2;
          $treeData{jewelModsTotal}{"$1#%$4"} += $2;
          push @{$jewelHash{implicitMods}}, \%modHash;
        } else {
          my %modHash;
          $modHash{"$mod"} = \1;
          push @{$jewelHash{implicitMods}}, \%modHash;
        }
      } 

      push @{$treeData{jewels}}, \%jewelHash;
    }



    # convert treeData to JSON
    my $jsonOut = JSON::XS->new->utf8->encode(\%treeData);
#    my $jsonOut = JSON::XS->new->utf8->pretty->encode(\%treeData);
#    print "--\n$jsonOut\n--\n";

    # Prepare for bulk adding to ES
    $bulk->index({ id => "$runDate-$league-$rank", source => "$jsonOut"});
  }
}

sub createNodeHash {
  # This URL should point to the official pathofexile.com skilltree
  my $fullSkilltreeURL = 'https://www.pathofexile.com/passive-skill-tree';
  
  # Fetch skilltree from pathofexile.com
  my $ua = LWP::UserAgent->new;
  my $response = $ua->get("$fullSkilltreeURL",'Accept-Encoding' => $can_accept);
  
  # Decode response
  my $content = join("", split(/\n/, $response->decoded_content));
  
  # Clean out everything before the skill tree data
  $content =~ s/^.*var passiveSkillTreeData = //o;
  # Clean out everything after the skill tree data
  $content =~ s/,\"imageZoomLevels.*$/\}/o;
 
  # Create the global nodeHash 
  our %nodeHash;
  
  # encode the JSON data into something perl can reference 
  my $data = decode_json(encode("utf8", $content));
  
  foreach $node (@{$data->{nodes}}) {
    my $id = $node->{id};
    # Create our own modified bonus hashes
    my @bonuses;
    foreach $bonus (@{$node->{sd}}) {
      if ($bonus =~ /(\.)(?!\d)/) {
        # Fix acrobatics
        if ($node->{dn} eq "Acrobatics") {
          push @bonuses, "30% Chance to Dodge Attacks";
          push @bonuses, "50% less Armour and Energy Shield";
          push @bonuses, "30% less Chance to Block Spells and Attacks";
        } else {
          # Change periods to commas
          $bonus =~ s/\./\,/g;
        push @bonuses, $bonus;
        }
      } else {
        push @bonuses, $bonus;
      }
    }
    $nodeHash{$id}{name} = $node->{dn};
    $nodeHash{$id}{icon} = "https://p7p4m6s5.ssl.hwcdn.net/image".$node->{icon};
    $nodeHash{$id}{icon} =~ s/\\//g;
    $nodeHash{$id}{isNoteable} = $node->{not};
    $nodeHash{$id}{isKeystone} = $node->{ks};
    $nodeHash{$id}{bonuses} = \@bonuses;
  }
}
