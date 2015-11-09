#!/usr/bin/perl

#print "Importing configuration file.\n";

our %conf;

# Open the config file and read it into a hash for reference
open(IN, "config") || die "ERROR: Unable to read config file! $!\n";
while(<IN>) {
  $line = $_;
  # Ignore any commented lines
  next if ($line =~ /^*#/);
  my ($option, $value) = split(/:/, $line);
  chomp($value);
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
  chomp($value);
  $conf{$option} = $value;
}

return true;
