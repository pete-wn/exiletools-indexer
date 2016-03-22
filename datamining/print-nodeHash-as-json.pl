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

# Create the %nodeHash lookup table for node information
&createNodeHash;

my $jsonOut = JSON::XS->new->utf8->pretty->encode(\%nodeHash);
print "$jsonOut\n";


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
