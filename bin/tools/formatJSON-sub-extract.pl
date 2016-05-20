#!/usr/bin/perl

# This just pulls the formatting stuff out of the process subroutine
# so it can be sent to another subroutine easily, it's not really
# intended to be used by anyone else probably ;)

$src = "../bin/process-reformat-ggg-to-pwx.pl";

open(my $fh, "<", $src) or die "ERROR opening $src - $!\n";
while(<$fh>) {
  my $line = $_;
  if ($line =~ /^# === BEGIN Item Processing Code Chunk/) {
    $active = 1;
  } elsif ($line =~ /^# === END Item Processing Code Chunk/) {
    $active = 0;
  } elsif ($active) {
    print "$line";
  }
}
close($fh);
