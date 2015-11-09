#!/usr/bin/perl

require("subs/sub.readConfig.pl");
require("subs/sub.currencyNames.pl");
require("subs/sub.currencyValues.pl");
require("subs/sub.itemBaseTypes.pl");
require("subs/sub.leagueHash.pl");
require("subs/sub.leagueApiNames.pl");
require("subs/sub.processLock.pl");

# Debug printing subroutine
sub d {
  print LOG "  ".$_[0] if ($debug);
  print "  ".$_[0] if ($debug);
}

return true;
