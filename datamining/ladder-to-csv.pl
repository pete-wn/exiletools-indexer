#!/usr/bin/perl

# This is a simple script to fetch the official Ladder for a league and output
# the data to a CSV file

$|=1;

use LWP::Curl;
use Data::Dumper;
use JSON;
use JSON::XS;
use Encode;
use utf8::all;

use Parallel::ForkManager;

$limit = 200;
$maxoffset = 74;
#$maxoffset = 1;
$dofullhistory = 0;

$league = $ARGV[0];
$outfile = $ARGV[1];

if ($league && $outfile) {
  open(OUT, ">$outfile") || die "ERROR: Unable to open $outfile - $!\n";
} else {
  die "You must specify a league and output file.\n";
}

#my $manager = new Parallel::ForkManager( 6 );
local $timestamp = time();
for (my $offset = 0; $offset <= $maxoffset; $offset++) {
  if (-f $errorfile) {
    my $error;
    open(ERROR, "$errorfile");
    while(<ERROR>) {
      $error .= $_;
    }
    close(ERROR);
    unlink($errorfile);
    unlink($lockfile);
    die "ERROR: Error File Populated - $error\n";
  }
#  $manager->start and next;
  my $status = &GetURL($offset * $limit, "$league");
#  $manager->finish;
}
print localtime()." [$league] Ladder update from GGG complete.\n";
$manager->wait_all_children;
print localtime()." Update Complete!\n";

exit;

sub GetURL {
  my $offset = $_[0];

  my $lwpcurl = LWP::Curl->new();
  my $url = "http://api.pathofexile.com/ladders/$league?offset=$offset&limit=$limit";
  print localtime()." GET: $league,$offset,$url\n";
  my $content;
  eval { $content = $lwpcurl->get("$url") };
 
  if ($@) {
    my $error = $@;
    print localtime()." WARNING: Get failed with \"$error\"!\n";
    open(ERROR, ">$errorfile");
    print ERROR "$error\n";
    close(ERROR);
    return;
  }


  $data = decode_json(encode("utf8", $content));

  for (my $entry=0; $entry <= $limit; $entry++) {
    if ($data->{entries}->[$entry]->{character}->{name}) {
      $totalcount++;
      my $id = "$data->{entries}->[$entry]->{account}->{name}.$data->{entries}->[$entry]->{character}->{name}";
      my $online = $data->{entries}->[$entry]->{online};
      my $accountName = $data->{entries}->[$entry]->{account}->{name};
      my $charName = $data->{entries}->[$entry]->{character}->{name};
      my $class = $data->{entries}->[$entry]->{character}->{class};
      my $level = $data->{entries}->[$entry]->{character}->{level};
      my $dead = $data->{entries}->[$entry]->{dead};
      my $experience = $data->{entries}->[$entry]->{character}->{experience};
      my $challenges = $data->{entries}->[$entry]->{account}->{challenges}->{total};
      my $rank = $data->{entries}->[$entry]->{rank};
      my $xph;
      my $xpGain;
      my $onlineTime;
      my $lastOnline;
# Change this to whatever format you want
#      print OUT "$accountName\n";
      print OUT "$league,$rank,$online,$accountName,$charName,$class,$level,$experience,$challenges\n";
#      print "$league,$data->{entries}->[$entry]->{rank},$data->{entries}->[$entry]->{account}->{name},$data->{entries}->[$entry]->{character}->{name},$data->{entries}->[$entry]->{online}\n";
    }
  }
}
