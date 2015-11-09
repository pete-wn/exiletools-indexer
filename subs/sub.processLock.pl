#!/usr/bin/perl

sub CreateLock {
  my $process = $_[0];
  my $timestamp = time();

  # Reconnect a DB session if it's not connected
  unless ($dbh->ping) {
    $dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";
  }

  # Check to see if this process is already locked
  my @lockStatus = $dbh->selectrow_array("SELECT `locked`,`timestamp` FROM `locks` WHERE `process`=\"$process\"");
  if ($lockStatus[0] == 1) {
    die "FATAL: $process was executed at ".localtime($timestamp)." but a lock is in place from ".localtime($lockStatus[1])."!\n";
  } else {
    &d("** Creating process lock for $process\n");
    $dbh->do("INSERT INTO `locks` VALUES
             (\"$process\",\"1\",\"$timestamp\",NULL,NULL)
             ON DUPLICATE KEY UPDATE
               `process`=\"$process\",
               `locked`=\"1\",
               `timestamp`=\"$timestamp\",
               `abort`=NULL,
               `abort-reason`=NULL
             ") || die "FATAL SQL ERROR creating process lock: $DBI::errstr\n";
  } 
}

sub RemoveLock {
  my $process = $_[0];
  my $timestamp = time();

  # Reconnect a DB session if it's not connected
  unless ($dbh->ping) {
    $dbh = DBI->connect("dbi:mysql:$conf{dbname}","$conf{dbuser}","$conf{dbpass}", {mysql_enable_utf8 => 1}) || die "DBI Connection Error: $DBI::errstr\n";
  }

  &d("** Removing process lock for $process\n");
  $dbh->do("UPDATE `locks` SET
             `process`=\"$process\",
             `locked`=\"0\",
             `timestamp`=\"$timestamp\",
             `abort`=NULL,
             `abort-reason`=NULL
           ") || die "FATAL SQL ERROR removing process lock: $DBI::errstr\n";


}

return true;
