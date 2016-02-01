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
  my $response = $ua->get("$ladderApiURL&league",'Accept-Encoding' => $can_accept);

  # Decode the returned data as a perl hash
  my %ladderData = %{eval $response->decoded_content};

  # Circuit breaker
  $count = 0;

  foreach $char (%ladderData) {
    if ($ladderData{$char}{rank} && $ladderData{$char}{accountName} && $ladderData{$char}{charName}) {
      $count++;
      last if ($count > 2000);
      &fetchTreeForChar("$ladderData{$char}{accountName}","$ladderData{$char}{charName}","$ladderData{$char}{rank}");
      usleep(400000);
    }
  }
  &sv("Bulk flushing data\n");
  $bulk->flush;
}

sub fetchTreeForChar {
  my $accountName = $_[0];
  my $character = $_[1];
  my $rank = $_[2];

  # Create a hash for the parsed tree data to be stored in
  my %treeData;
  $treeData{info}{accountName} = $accountName;
  $treeData{info}{accountNameTokenized} = $accountName;
  $treeData{info}{characterTokenized} = $character;
  $treeData{info}{character} = $character;
  $treeData{info}{rank} += $rank;
  $treeData{info}{runDate} = $runDate;

  # Fetch skilltree from pathofexile.com
  my $response = $ua->get("$skilltreeURL&accountName=$accountName&character=$character",'Accept-Encoding' => $can_accept);
 
  # Decode response
  my $content = $response->decoded_content;

  if ($content eq "false") {
    # If the content is false then this character is private or deleted, ignore it
    &d("$accountName $character $rank is private!\n");
    $treeData{info}{private} = \1;
  } elsif ($content =~ /DOCTYPE html/) {
    # WTF this is HTML?
    &d("Got some weird HTML for $character on $accountName rank $rank?\n--\n$content\n--\n");
  } else {
    &d("Got data for $accountName $character $rank\n");
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
    foreach $point (@{$data->{hashes}}) {
      $skillPointCount++;
      my %nodeHash;
      $nodeHash{node} += $point ;
      $nodeHash{chosen} = \1;
      push @{$treeData{skillNodes}}, \%nodeHash;

      # If this is a jewel node, increment the jewel count
      $jewelPointCount++ if ($jewelNodes{$point});
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
        if ($mod =~ /^(.*?)+(\d+(\.\d{1,2})?)(.*?)$/) {
          my %modHash;
          $modHash{"$1+#$4"} += $2;
          push @{$jewelHash{explicitMods}}, \%modHash;
        } elsif ($mod =~ /^(.*?)(\d+(\.\d{1,2})?)\%(.*?)$/) {
          my %modHash;
          $modHash{"$1#%$4"} += $2;
          push @{$jewelHash{explicitMods}}, \%modHash;
        } else {
          my %modHash;
          $modHash{"$mod"} = \1;
          push @{$jewelHash{explicitMods}}, \%modHash;
        }
      }

      # Repeat for implicit mods - yes this is lazy copy pasting the same code
      foreach $mod (@{$jewel->{implicitMods}}) {
        if ($mod =~ /^(.*?)+(\d+(\.\d{1,2})?)(.*?)$/) {
          my %modHash;
          $modHash{"$1+#$4"} += $2;
          push @{$jewelHash{implicitMods}}, \%modHash;
        } elsif ($mod =~ /^(.*?)(\d+(\.\d{1,2})?)\%(.*?)$/) {
          my %modHash;
          $modHash{"$1#%$4"} += $2;
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
#    print "--\n$jsonOut\n--\n";

    # Prepare for bulk adding to ES
    $bulk->index({ id => "$runDate-$rank", source => "$jsonOut"});
  }
}
