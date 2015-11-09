#!/usr/bin/perl

sub CreateLock {
  my $process = $_[0];
  my $timestamp = time();
  $dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";

  # Check to see if this process is already locked
  my $lockStatus = $dbh->selectrow_array("SELECT `locked` FROM `locks` WHERE `process`=\"$process\"");
  if ($lockStatus == 1) {
    print "Warning, $process is already locked!\n";
    return 1;
  } else {
    print "It's cool let's add a lock for $process.\n";
    return 0;
  } 

}

sub RemoveLock {



}

return true;
