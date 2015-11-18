#!/usr/bin/perl

require("subs/sub.readConfig.pl");
require("subs/sub.currencyNames.pl");
require("subs/sub.currencyValues.pl");
require("subs/sub.itemBaseTypes.pl");
require("subs/sub.leagueHash.pl");
require("subs/sub.leagueApiNames.pl");
require("subs/sub.processLock.pl");

# Debug printing subroutine - this is for standard non-quiet logging, it gives
# some information about what is happening but not too much.
sub d {
  print localtime()." $_[0]" if ($debug);
}

# Super Verbose printing subroutines, for ultra debug. Gives a TON of information.
sub sv {
  print localtime()." $_[0]" if ($sv);
}


# Subroutine for starting up, including locks/etc.
sub StartProcess {
  # Get the start time in epoch for analysis
  our $startTime = time();

  # Keep track of what this program is based on the name
  our $process = $0;
  # This is clumsy, we can probably do this better.
  if ($process =~ /\//) {
    $process =~ s/.*?\///g;
  }

  # Actually, just default to debug on for everything
  # debug is really a poor choice, it's more like "show anything on screen"
  our $debug = 1;

  our %args;
  # Get the command line arguments and set things appropriately
  while (my $arg = shift(@ARGV)) {
    if ($arg eq "-v") {
      our $debug = 1;
      print "Options: debug=1\n";
    } elsif ($arg eq "-sv") {
      our $sv = 1;
      print "Options: sv=1\n";
    } elsif ($arg eq "-full") {
      $args{full} = 1;
    } elsif ($arg eq "-unlock") {
      &RemoveLock("$process");
    } else {
      $arg =~ s/^\-//o;
      $args{$arg} = shift(@ARGV);
      print "Options: $arg=$args{$arg}\n";
    }
  }

  # Establish database connection for primary thread
  $dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";

  &d("* $process started\n");

  # Create a lock to prevent multiple processes from running at once
  &CreateLock("$process");
}

sub ExitProcess {
  # Remove the lock
  &RemoveLock("$process");

  # Disconnect any dbh sessions
  $dbh->disconnect if ($dbh->ping);

  # Get the end time in epoch for analysis
  our $endTime = time();
  
  &d("* [".($endTime - $startTime)." seconds] $process completed, exiting.\n");
  exit;
}

return true;
