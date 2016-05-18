#!/usr/bin/perl

# This script gets character skilltrees from a list of characters
# https://www.reddit.com/r/pathofexiledev/comments/4au3py/datamining_in_progress_large_scale_ascendancy/

$|=1;

use LWP::UserAgent;
use Data::Dumper;
use JSON;
use JSON::XS;
use Encode;
use utf8::all;
use Time::HiRes qw(usleep);
use Search::Elasticsearch;


# The official pathofexile.com URL for getting character skilltree data
$skilltreeURL = 'https://www.pathofexile.com/character-window/get-passive-skills?reqData=0';

# Create the %nodeHash lookup table for node information
&createNodeHash;

# You just gotta get this right
$srcData = $ARGV[0];


# Set global rundate variable
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
our $runDate = ($year + 1900).sprintf("%02d", ($mon + 1)).sprintf("%02d", $mday);

&fetchSkilltrees;

# == Exit cleanly
exit;

sub fetchSkilltrees {
  local $league = $_[0];

  local $publicCount = 0;
  local $totalCount = 0;

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

  # Circuit breaker
  $count = 0;

  open(IN, "$srcData") || die "ERROR opening $srcData - $!\n";
  while(<IN>) {
    chomp;
    my @line = split(/\,/, $_);
    $count++;
#    last if ($count > 500);
    if ($count % 500 == 0) {
      &d("$count characters processed\n");
    }
    &fetchTreeForChar("$line[0]","$line[1]","$line[2]","$line[3]","$line[4]","$line[5]","$line[6]");
    usleep(200000);
    
  }

  &sv("Bulk flushing data\n");
  $bulk->flush;

  &d("Total Characters Checked: $totalCount\n");
  &d("Total Characters Public: $publicCount\n");
}

sub fetchTreeForChar {
  my $accountName = $_[0];
  my $character = $_[1];
  my $league = $_[2];
  my $level = $_[3];
  my $classID = $_[4];
  my $class = $_[5];
  my $ascendancyID = $_[6];

  $totalCount++;

  # Create a hash for the parsed tree data to be stored in
  my %treeData;
  $treeData{info}{accountName} = $accountName;
  $treeData{info}{accountNameTokenized} = $accountName;
  $treeData{info}{characterTokenized} = $character;
  $treeData{info}{character} = $character;
  $treeData{info}{league} = $league;
  $treeData{info}{runDate} = $runDate;
  $treeData{info}{level} = $level;
  $treeData{info}{class} = $class;
  $treeData{info}{classID} += $classID;
  $treeData{info}{ascendancyID} += $ascendancyID;

  # Fetch skilltree from pathofexile.com
  my $response = $ua->get("$skilltreeURL&accountName=$accountName&character=$character",'Accept-Encoding' => $can_accept);
 
  # Decode response
  my $content = $response->decoded_content;

  if ($content eq "false") {
    # If the content is false then this character is private or deleted, ignore it
    &d("$accountName $character is private!\n");
    $treeData{info}{private} = \1;
    # convert treeData to JSON
    my $jsonOut = JSON::XS->new->utf8->encode(\%treeData);
    # Prepare for bulk adding to ES
    $bulk->index({ id => "$runDate-$league-$character", source => "$jsonOut"});

  } elsif ($content =~ /DOCTYPE html/) {
    &d("$accountName $character $rank is probably utf8 or something, got HTML response.\n");
  } else {
    &d("Got data for $accountName $character $rank\n");
    $publicCount++;
    $treeData{info}{private} = \0;
    $treeData{info}{url} = "$skilltreeURL&accountName=$accountName&character=$character";

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
    my $ascendancySkillPointCount = 0;
    my $jewelPointCount = 0;
    foreach $id (@{$data->{hashes}}) {
      next if ($nodeHash{$id}{isAscendancyStart});
      next if ($nodeHash{$id}{isMultipleChoice});
      if ($nodeHash{$id}{ascendancyName}) {
        $ascendancySkillPointCount++;
      } else {
        $skillPointCount++;
      }
      my %nHash;
      $nHash{node} += $id ;
      $nHash{chosen} = \1;
      $nHash{nodename} = $nodeHash{$id}{name};
      $nHash{isNoteable} = $nodeHash{$id}{isNoteable} if ($nodeHash{$id}{isNoteable});
      $nHash{isKeystone} = $nodeHash{$id}{isKeystone} if ($nodeHash{$id}{isKeystone});
      $nHash{isAscendancyStart} = $nodeHash{$id}{isAscendancyStart} if ($nodeHash{$id}{isAscendancyStart});
      $nHash{ascendancyName} = $nodeHash{$id}{ascendancyName} if ($nodeHash{$id}{ascendancyName});
      $nHash{isAscendancyNode} = \1 if ($nodeHash{$id}{ascendancyName});
      $nHash{isMultipleChoiceOption} = $nodeHash{$id}{isMultipleChoiceOption} if ($nodeHash{$id}{isMultipleChoiceOption});
      $nHash{icon} = $nodeHash{$id}{icon};

      $treeData{info}{class} = $nodeHash{$id}{ascendancyName} if ($nodeHash{$id}{ascendancyName});
      $treeData{info}{ascendancyName} = $nodeHash{$id}{ascendancyName} if ($nodeHash{$id}{ascendancyName});
     

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
    $treeData{info}{ascendancySkillPointsUsed} += $ascendancySkillPointCount;
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
    $bulk->index({ id => "$runDate-$league-$character", source => "$jsonOut"});
  }
}

sub d {
  print localtime." $_[0]";
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

  open(OUT, ">/tmp/content");
  print OUT $content;
  close(OUT);
  
  # encode the JSON data into something perl can reference 
  my $data = decode_json(encode("utf8", $content));
  
  foreach $node (@{$data->{nodes}}) {
    my $id = $node->{id};

    # Create our own modified bonus hashes
    my @bonuses;
    if ($node->{dn} eq "Passive Point") {
      push @bonuses, "Grants 1 Passive Point";
    }
    if ($node->{isAscendancyStart}) {
      push @bonuses, "Ascendancy Start for $node->{ascendancyName}";
    }
    if ($node->{isMultipleChoice}) {
      push @bonuses, "Choose a Skill";
    }
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
          $bonus =~ s/\n/ /g;
          push @bonuses, $bonus;
        }
      } else {
        $bonus =~ s/\./\,/g;
        $bonus =~ s/\n/ /g;
        push @bonuses, $bonus;
      }
    }

    $nodeHash{$id}{name} = $node->{dn};
    $nodeHash{$id}{icon} = "https://p7p4m6s5.ssl.hwcdn.net/image".$node->{icon};
    $nodeHash{$id}{icon} =~ s/\\//g;
    $nodeHash{$id}{isNoteable} = $node->{not} if ($node->{not});
    $nodeHash{$id}{isKeystone} = $node->{ks} if ($node->{ks});
    $nodeHash{$id}{bonuses} = \@bonuses;
    $nodeHash{$id}{isAscendancyStart} = $node->{isAscendancyStart} if ($node->{isAscendancyStart});
    $nodeHash{$id}{ascendancyName} = $node->{ascendancyName} if ($node->{ascendancyName});
    $nodeHash{$id}{isMultipleChoiceOption} = $node->{isMultipleChoiceOption} if ($node->{isMultipleChoiceOption});
    $nodeHash{$id}{isMultipleChoice} = $node->{isMultipleChoice} if ($node->{isMultipleChoice});
  }
}

sub sv {
  print localtime." $_[0]";
}
