# ExileTools Indexer

This is a work in progress: an update of the Exile Tools Indexer, fully open sourced.

## Why?

There are a few major reasons I'm doing this:

1. The indexer itself grew very organically over the last year and is now very messy and a bit inefficient. For example, there is no reason to save data files to disk anymore, and it reads from a ton of different databases.
2. Github will help me track improvements and changes in order to streamline the system
3. If someone else wants to contribute or just run their own indexer, they can
4. Interested people can see some of the weird stuff that goes into this and maybe give me some better ideas about things

## Requirements

The Exile Tools Indexer requires:

1. Perl w/ many modules
2. MariaDB server
3. ElasticSearch server

# Indexer Pipeline

This section explains the basic Indexer Pipeline process, which is composed of multiple scripts designed to be run regularly in sequence, or individually as necessary to update specific targets in the pipeline.

The pipeline as intended to be run via a Job Scheduler which can track failure or success, log the runs, and prevent overruns. It can also be run directly from the command line. A database lock is used to prevent multiple instances of each process in the pipeline from running at the same time - a FATAL error will retain the lock for that process and prevent further execution until the problem is resolved.

At exiletools.com, the pipeline is run approximately every ten minutes via Jenkins, with errors triggering an e-mail alert.

##1. get-forum-threads.pl

This is the primary pipeline process which goes to pathofexile.com, checks the Shop Forums for updates, downloads any new threads, and processes these threads into a database.

1. Create a list of active forums to be scanned (defined in the `league-list` table). Each forum is processed in a separate fork, allowing multi-threading of forum processing.
2. Load the forum index pages and scan for threads - this is repeated to a depth defined in the script (default, 8 pages). The thread information is compared to data stored in `web-post-track` to determine threads which are new, modified, or unchanged based on the lastpost time.
3. After each index page load, new or modified threads in that page are fetched linearly and their information is updated in `web-post-track`
* Fetched shop pages have a copy saved to disk, but are processed from memory.
* The json data from the page is encoded into a Perl readable format
* The first post in the page is scanned for items and prices.
* Each item is then inserted into a row in `items` based on its internal UUID (`threadid:md5sum` of the JSON data), marked as added if new, modified if it existed previously but the price changed, or updated if it has just been verified again.
* The item's JSON data is inserted into the `raw-json` table
* After processing the shop thread, the items in the database for that thread are compared to the current update. Any items which were in previous updates but not the current update are marked as GONE.
* Some basic statistics about the update are stored in `thread-update-history`, with a copy of the latest row of stats written into `thread-last-update` (this allows faster querying for latest updates)
4. Some basic statistics about the run is saved into `fetch-stats`
5. Runs a subroutine to find any items which have not been updated in the last X days (default: 7) and automatically mark them with a `verified` status of `OLD` (this typically applies to items in abandoned threads which are no longer being indexed)

Notes:

* A copy of each thread is stored on disk in uncompressed HTML as fetched from pathofexile.com. These files are the ultimate point of record, and allow the database to be completely rebuilt from historical source. This is useful for re-loading data in the event of a newly discovered code bug (such as bad b/o detection), or re-loading data from a structural change to the web formatting that requires code changes.

* At Exile Tools, this data is stored on a mount with in-line compression and deduplication enabled which results in an average of ~70% savings, so the ~700GB of historical thread data retained only uses ~210GB of space.

* The archival of this thread data can be disabled by removing the relevant portion of the code. The regular pipeline process does not reference or require these files.

##2. format-and-load-db-to-es.pl

This is the secondary pipeline process which takes all modified items from the database, re-formats them to a more powerful indexable JSON format, then bulk loads them into ElasticSearch.

1. Fetches metadata about all threads from `thread-last-update` 
2. Processes the `items` table for all items with the `inES` column set to `no`
3. For each item found, pulls the item's metadata from `items` and JSON data from `raw-json`
4. Performs heavy parsing and iteration to build a better JSON format
5. Bulk loads new items into the ElasticSearch index

Notes:

* Why load from the DB instead of processing the items into ElasticSearch directly from memory during get-forum-updates.pl: This is currently a separate process to ensure that all item/thread data is properly loaded before building the ES JSON data as well as to ensure that any errors in the get-forum-threads.pl process do not result in partial/incomplete ES data. Finally, it allows me to run a bulk load of items from the DB into ElasticSearch on demand without using other code. I may integrate the ES loading into get-forum-threads.pl in the future.

* This process is multi-fork and bulk capable, with loading speed depending primarily on IO and tuning of the ES instance and database. At Exile Tools, I achieve an average bulk loading rate of ~4000 items/second on spinning disk. This appears to be mostly limited by the speed of database selects from `raw-json` with tokudb due to the spinning disk backend. Memory cache on the database is tuned to limit this as much as possible by keeping recent inserts/updates in memory from the get-forum-threads.pl process.
