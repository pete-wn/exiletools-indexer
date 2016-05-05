#!/usr/bin/perl

# Simple tool to monitor the indexing rate for testing since Marvel gets weird


use LWP::UserAgent;
use JSON::XS;
use Time::HiRes qw(usleep);

our $ua = LWP::UserAgent->new;


my $keepRunning = 1;
while($keepRunning) {
  my $response = $ua->get("http://localhost:9200/poedev/_stats/indexing");

  my $content = $response->content;
  my $data = JSON::XS->new->decode($content);

  my $total = $data->{indices}->{poedev}->{total}->{indexing}->{index_total};
  $firstTotal = $total unless ($firstTotal);

  if (($total > $lastTotal) && ($lastTotal)) {
    print localtime()." | +".($total - $lastTotal)." docs | ".sprintf("%.2f", (($total - $lastTotal) / 10))." docs / second | ".sprintf("%.2f", (($total - $firstTotal) / ($runCount * 10)))." docs / second over last ".($runCount * 10)."s (".($total - $firstTotal)." docs)\n";
  }


  sleep 10;
  $runCount++;
  $lastTotal = $total;


}
