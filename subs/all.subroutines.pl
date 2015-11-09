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
  # Keep track of what this program is based on the name
  our $process = $0;
  # This is clumsy, we can probably do this better.
  if ($process =~ /\//) {
    $process =~ s/.*?\///g;
  }

  # Establish database connection for primary thread
  $dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";

  &d("$process started\n");

  # Create a lock to prevent multiple processes from running at once
  &CreateLock("$process");
}

sub ExitProcess {
  # Remove the lock
  &RemoveLock("$process");

  # Disconnect any dbh sessions
  $dbh->disconnect if ($dbh->ping);
  
  &d("$process completed, exiting.\n");
  exit;
}

return true;
