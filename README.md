# ExileTools Indexer

This is a work in progress: an update of the Exile Tools Indexer, fully open sourced.

## Why?

There are a few major reasons I'm doing this:

1. The indexer itself grew very organically over the last year and is now very messy and a bit inefficient. For example, there is no reason to save data files to disk anymore, and it reads from a ton of different databases.
2. Github will help me track improvements and changes in order to streamline the system
3. If someone else wants to contribute or just run their own indexer, they can
4. Interested people can see some of the weird stuff that goes into this and maybe give me some better ideas about things

## Right Now

As of Day 1 when I've uploaded this, the indexer consists of three main scripts:

1. get-forum-threads.pl : Grabs the latest forum data and saves raw html files on disk
2. load-data-from-disk.pl : Imports the latest raw html files into a database
3. format_and_load_db_to_es.pl : Modifies all the items into a good ElasticSearch format and loads them into ES

#### Why the intermittent files and database?

Originally I saved copies of files so that if I needed to re-parse everything into the DB, I could. For example, let's say I realized
that a regexp for buyouts wasn't matching a common format - I could just modify it then re-upload everything.

The same logic applies for putting the data into a database first. That part is going to stay - the database will act as a source of record for ElasticSearch if I need to re-index, as GGG has been known to mess some things up.


