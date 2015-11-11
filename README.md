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

1. Perl w/ many modules (detail to be added, but perl will tell you)
2. MariaDB server
3. ElasticSearch server

# Indexer Pipeline

This section explains the basic Indexer Pipeline process, which is composed of multiple scripts designed to be run regularly in sequence, or individually as necessary to update specific targets in the pipeline.

The pipeline as intended to be run via a job scheduler which can track failure or success, time/log the runs, and prevent overruns. It can also be run directly from the command line. A database lock is used to prevent multiple instances of each process in the pipeline from running at the same time - a FATAL error will retain the lock for that process and prevent further execution until the problem is resolved.

At exiletools.com, the pipeline is run approximately every ten minutes via Jenkins, with errors triggering an e-mail alert. A resource lock on pathofexile.com is used to prevent the Indexer Pipeline from running at the same time as any other system which fetches data from pathofexile.com (such as my Ladder API back-end).

##1. get-forum-threads.pl

This is the primary pipeline process which goes to pathofexile.com, checks the Shop Forums for updates, downloads any new threads, and processes these threads into a database.

1. Create a list of active forums to be scanned (defined in the `league-list` table). Each forum is processed in a separate fork, allowing multi-threading of forum processing.
2. Load the forum index pages and scan for threads - this is repeated to a depth defined in the script (default, 8 pages - at the beginning of leagues, I often need to change this to 16-20 pages as shops are updated much more frequently). The thread information is compared to data stored in `web-post-track` to determine threads which are new, modified, or unchanged based on the lastpost time.
3. After each index page load, new or modified threads in that page are fetched linearly and their information is updated in `web-post-track`
* Fetched shop pages have a copy saved to disk, but are processed from memory
* The json data from the page is encoded into a Perl readable format
* The first post in the page is scanned for items and prices.
* Each item is then inserted into a row in `items` based on its internal UUID (`threadid:md5sum` of the JSON data), marked as added if new, modified if it existed previously but the price changed, or updated if it has just been verified again.
* The item's JSON data is inserted into the `raw-json` table
* After processing the shop thread, the items in the database for that thread are compared to the current update. Any items which were in previous updates but not the current update are marked as GONE.
* Some basic statistics about the update are stored in `thread-update-history`, with a copy of the latest row of stats written into `thread-last-update` (this allows faster querying for latest updates)
4. Some basic statistics about the run are saved into `fetch-stats`
5. Runs a subroutine to find any items which have not been updated in the last X days (default: 7) and automatically mark them with a `verified` status of `OLD` (this typically applies to items in abandoned threads which are no longer being indexed)

Notes:

* A copy of each thread is stored on disk in uncompressed HTML as fetched from pathofexile.com. These files are the ultimate point of record, and allow the database to be completely rebuilt from historical source. This is useful for re-loading data in the event of a newly discovered code bug, or re-loading data from a structural change to the web formatting that requires code changes (see the FAQ for more detail on why I do this). It's also very nice to be able to test/dev/troubleshoot by reading an input file instead of making repeated web requests.

* At Exile Tools, this data is stored on a mount with in-line compression enabled which results in an average of ~70% savings. As a result, the ~700GB of historical thread data retained since July 2014 only uses ~210GB of space. 

* The archival of this thread data can be disabled by removing the relevant portion of the code. The regular pipeline process does not reference or require these files.

##2. format-and-load-db-to-es.pl

This is the secondary pipeline process which takes all modified items from the database, re-formats them to a more powerful indexable JSON format, then bulk loads them into ElasticSearch.

1. Fetches metadata about all threads from `thread-last-update` 
2. Processes the `items` table for all items with the `inES` column set to `no`
3. For each item found, pulls the item's metadata from `items` and JSON data from `raw-json`
4. Performs heavy parsing and iteration to build a better JSON format
5. Bulk loads new items into the ElasticSearch index

Notes:

* This is currently a separate process to ensure that all item/thread data is properly loaded before building the ES JSON data as well as to ensure that any errors in the get-forum-threads.pl process do not result in partial/incomplete ES data. See the FAQ for more detail on why I load ES from the DB instead of directly from HTML.

* This process is multi-fork and bulk capable, with loading speed depending primarily on IO and tuning of the ES instance and database. At Exile Tools, I achieve an average bulk loading rate of ~4000 items/second on spinning disk. This appears to be mostly limited by the speed of database selects from `raw-json` with tokudb due to the spinning disk backend. Memory cache on the database is tuned to limit this as much as possible by keeping recent inserts/updates in memory from the get-forum-threads.pl process. 

* Average run-time for this process during a routine index is measured in seconds.

# F.A.Q.

Actually, none of these are "frequently" asked, but you may be wondering...

### Why maintain two separate points of record instead of loading directly into ElasticSearch?

I maintain two points of record (original HTML files and items in the database) prior to ElasticSearch to enable rebuilding of index data in response to changes that the parser does not handle or to add features as needed.

**Original HTML Files:**

Re-loading from the original HTML is a more burdensome process that requires inefficient file IO. This is required when new thread parsing features are added or when the underlying page formatting changes. Re-loading from HTML is done very rarely, but it has proven to be necessary at times.

*Examples:*

* ProFalseIdol requested that I track the shop thread title, which was previously unparsed. I added detection for the shop thread title to the HTML parsing then re-loaded all recent pages with it in order to populate this field for the index.

* When re-factoring the code to use HTML::Tree instead of just advanced regexp iteration, frequent testing was required on the raw HTML pages. Fetching stored pages from disk allowed me to test on thousands of original files at local disk IO speeds instead of fetching them from pathofexile.com.

* If the HTML layout ever changes, it might take me days to respond and update the parser. By storing a local copy of the original thread, I can simply re-load all the pages indexed since the changes without losing any data. This has occurred a couple of times since I started indexing data.

**Storing JSON and Item Data in the Database:**

The Elastic Search JSON format for items is constantly changing and updating. Storing basic item data and the original item JSON data in a database allows me to quick re-load items into the ES index with new formatting or completely re-build the ES index on demand. This gives me the ability to improve the item ES JSON format on the fly and immediately update all items. 

It also allows me to occasionally clean up mistakes in the Dynamic Mapping caused by strange formatting in the original item JSON data.

*Examples:*

* GGG once randomly added a bunch of special characters to item JSON data that resulted in a ton of messed up data being loaded and corrupted the index. The fix for this was literally one line of code to strip these characters from the JSON data, and I was able to rebuild and rapidly re-index all the items from the database in a few hours (the index at the time was 50 million items). Without the database or original files as points of record, I would have been forced to destroy all historical data.

* Item types are often added or changed in patches, and it may take me days or weeks before I notice and update the lookup tree for these. Re-indexing these items from the database allows me to rapidly fix these. (a recent specific example, the change from `Fossilised Shield` to `Fossilized Shield` resulted in all `Fossilized Shields` having an `Unknown` type - re-indexing these from the database was much easier than re-building them within ES)

* I occasionally add new information to the ES item JSON, and it's quicker/easier to simply rebuild the items from the original JSON data than it is to pull them from ES to rebuild.

* Because I use bulk loading into ES, any problems can result in thousands of items not making it into the index. With these items tracked in the database, it is very easy to re-index them.

### Why Perl? Why is your code so sloppy? Why do you use that regexp instead of *magic thingie #3*? Ewww.

I Am Not A Developer (or a Programmer). Aside from programming in BASIC and Pascal growing up, my adult technical background is in systems and infrastructure. I've been using Perl to get things done for 20+ years - but to me, it was always a *swiss army knife* and I wrote *hacks and scripts*, not code or programs. If you look at my code, I still have some weird conventions and habits that were formed back then (`use strict` was for time wasting suckers), because I haven't really needed to learn or use anything else since (I can read/adapt code in many languages, but starting from scratch I'll always go with Perl).

The result is a bunch of weird code that looks like some dude wrote it twenty years ago because I'm basically still writing code like it's 1995. I've recently tried to do more cool stuff like actually use perl modules instead of parsing everything myself (such as converting my ghetto parsing to using HTML::Tree), but mostly I'm stuck in the past.

This code is what happens when an infrastructure guy duct tapes a bunch of crap together to make it work. In my world, Perl is still the duct tape of the internet. \o/
