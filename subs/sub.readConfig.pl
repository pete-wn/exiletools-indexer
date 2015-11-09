#!/usr/bin/perl

# Open the config file and read it into a hash for reference
my %conf;
open(IN, "config") || die "ERROR: Unable to read config file! $!\n";
while(<IN>) {
  $line = $_;
  # Ignore any commented lines
  next if ($line =~ /^*#/);
  my ($option, $value) = split(/:/, $line);
  $conf{$option} = $value;
}
close(IN);

# Open the "hidden" db credentials file and add it to config hash
open(IN, "$conf{dbcreds}") || die "ERROR: Unable to read db credentials file ($conf{dbcreds})! $!\n";
while(<IN>) {
  $line = $_;
  # Ignore any commented lines
  next if ($line =~ /^*#/);
  my ($option, $value) = split(/:/, $line);
  $conf{$option} = $value;
}

return true;
