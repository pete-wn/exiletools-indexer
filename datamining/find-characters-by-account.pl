#!/usr/bin/perl

# This script will create a list of characters for an account based on certain criteria to be
# used in datamining. It takes a single argument, which should be a full path to a list of account names
# to datamine.
#
# IMPORTANT: There is no validation of account names. Use a proper list ok?

$|=1;

use LWP::UserAgent;
use Data::Dumper;
use JSON::XS;
use Encode;
use utf8::all;
use Time::HiRes qw(usleep);

# Change these as appropriate!
our $minLevel = "49";
our $reqLeague = "Perandus";
open(our $OUT, ">", "character-list.csv") || die "FATAL: Unable to open character list for output!\n";
select((select($OUT), $|=1)[0]);

our $charURL="https://www.pathofexile.com/character-window/get-characters";

# Create a user agent
our $ua = LWP::UserAgent->new;
# Make sure it accepts gzip
our $can_accept = HTTP::Message::decodable;

open(IN, "$ARGV[0]") || die "ERROR: Unable to open $ARGV[0] for input!\n";
while(<IN>) {
  my $target = $_;
  chomp($target);
  &getChars("$target");
  usleep(150000);
}
close(IN);


sub getChars {
  my $accountName = $_[0];
  print localtime." Getting character list for \'$accountName\'... ";

  my $response = $ua->get("$charURL?accountName=$accountName",'Accept-Encoding' => $can_accept);
  if ($response->is_success) {
    my $content = $response->decoded_content;
    if ($content =~ /^false/) {
      print " PRIVATE!\n";
      return;
    }

    my $data = decode_json(encode("utf8", $content));
    my $charCount = 0;
    # Parse the characters
    foreach $character (@{$data}) {
      next unless (($character->{league} eq $reqLeague) && ($character->{level} > $minLevel));
      print $OUT "$accountName,$character->{name},$character->{league},$character->{level},$character->{classId},$character->{class},$character->{ascendancyClass}\n";
      $charCount++;
    }
    print "$charCount matching chars logged.\n";
  } else {
    print "Something went wrong - ".$response->status_line."\n";
  }
}
