#!/usr/bin/perl

# A simple script to output data on the popularity of various ascendancy
# classes from character-list.csv

# character-list.csv is:
# accountName,charName,League,Level,ClassID,ClassName,AscendancyCount
#
# Output will be formatted for reddit

open(IN, "character-list.csv") || die "ERROR: Unable to open character-list.csv! $!\n";
while(<IN>) {
  chomp;
  my @line = split(/\,/, $_);
  next if ($line[6] < 1);
  $a{"$line[5]"}++;
  $total++;
}
close(IN);

print "|Ascendancy|Count|Percent|\n";
print "|--|--|--|\n";
foreach $k (sort {$a{$b} <=> $a{$a}} keys %a) {
  print "|$k|$a{$k}|".sprintf("%.2f", ($a{$k}/$total*100))."|\n";

}
