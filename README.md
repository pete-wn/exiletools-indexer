# ExileTools Indexer v4

This project contains the open source indexer back-end used by ExileTools for its free ElasticSearch API service, a searchable index of all items for sale (or recently for sale) by players of Path of Exile using the Stash Tab API service from Grinding Gear Games.

You may use this code to run your own private or public index, contribute to this code, or simply learn from it. My only request is that you avoid trying to recognize revenue via direct use of my code.

# What's New in Version 4?

v4 of the Indexer Core completes a huge optimization re-factor designed to ensure the indexer is capable of processing peak data from the Stash Tab API in real time. Monitoring the official Stash Tab API data and processing this data is now down asynchronously using Kafka, and processing threads can be scaled up with minimal overhead.

The end result is that items should appear inside the ElasticSearch index within ~10s of the update via the Stash Tab API even during peak periods.

# Do you need to run this? ExileTools makes the data available publicly for free!

If all you're looking for is direct access to an index, check out the free ElasticSearch API service by ExileTools - no need to run your own!

http://api.exiletools.com/info/indexer.html

You can get up and running in literally seconds with Elastic Search queries against live Stash Tab data. For hundreds of example queries to get you started, check out http://gist.github.com/trackpete or look at some of the AngularJS code in the front ends included in this project! The indexer page above also contains very detailed explanations of the Elastic Search mapping.

# What the Stash Tab Indexer Does

When a player modifies any item in their public stash tabs the stash tab is pushed out in a river based JSON API service. The `incoming-monitor-ggg-stashtab-api.pl` daemon constantly monitors this river and pushes updates into a Kafka topic for processing. This daemon is effectively limited by the transfer rate capabilities of GGG's API and by default only checks for updates every few seconds.

A second series of parallel daemons (`process-reformat-ggg-to-pwx.pl`) constantly monitor these Kafka topics for new items, process them (including reformatting for ElasticSearch, analyzing historical data, etc.), and bulk index them to ElasticSearch. Changes are processed in near-realtime, with item updates showing up in ElasticSearch typically within 10s of being pushed to the Stash Tab API.

The default item JSON data is poorly optimized for searching, thus the majority of the processing that takes place in the Indexer Core is a complete re-building of the item from the ground up using. This building of a new item JSON structure translates better into ElasticSearch, and consists of the following general changes:

* The item type is detected from the name and stats, including where it can be equipped and what it is
* Mods are detected and converted into searchable values
* Psuedo and Total mods are calculated
* Properties of the item are broken down into easier to index fields
* Some additional properties are calculated (i.e. DPS)
* Price is made searchable and indexed with a fixed-rate chaosEquiv value added for sorting
* Socket information is converted into an easier to use form
* All general item information is broken out into easily indexed and searched fields
* General shop information is added to the item, such as when it was added, if it's still available, when it was last modified, etc.

This mapping is documented in detail on the Index JSON Structure page at ExileTools: http://api.exiletools.com/info/indexer-docs.html

# Requirements

As of this writing, you will need the following to run the Indexer Core on your own server:

1. ElasticSearch v2.3+
  * You will need an item index and a stats index. Simple example scripts to create this can be found in `bin/tools/setup`
2. Perl v5.10+
  * You will need a number of perl modules to run the various perl programs. Information on installing these modules is available in `docs/INSTALL.txt`
3. Apache Kafka v0.9+
  * Information on setting up topics is available in `docs/INSTALL.txt`
4. Supervisor is highly recommended to keep the daemons running
5. A decent server and internet pipe
  * I would recommend at least a quad core server with 16GB of RAM and an SSD on a connection that can handle 200-300GB+/mo of data transfer

For more information on installing the Indexer Core, take a look at `docs/INSTALL.txt`

# What Else is Included?

This GitHub project also includes a number of related and supporting projects for the Indexer, typically hosted on ExileTools.com. Some of these projects include:

1. `www` : Various web front and back ends, some of which may be under random development at any time, including:
  * `cgi-bin/item-report-*` : Back end for the Price Macro tool, under re-development
  * `html/shop-watcher.html` : (AngularJS) [v3] Monitors a sellerAccount in the index to show modifications made via the Public Stash Tab API 
  * `html/dashboard.html` : (AngularJS) [v2] Statistics Dashboard about index *needs updating to v3*
  * `html/uniques.html` : (AngularJS) [v2] Unique Item Price Reports *needs updating to v3*
  * `html/skilltree-explorer.html` : (AngularJS) [WIP] An experiment for exploring skilltrees, possibly abandoned
  * `html/skilltree-elasticui.html` : (AngularJS) [WIP] Another experiment for exploring skilltrees
  * `js` and `css` : Supporting files, including a bunch of thirdpart javascript

2. `related/ladder-skilltrees` : Tools to store the top player's skilltree information in an ES Index

3. `bin/tools` : Various supporting tools, usually intended to be run from the root directory
  * `bin/tools/watch-modified-items.pl` : Dumps information about recently modified items in the ES index to confirm items are being processed. Unlike log output from the daemons, this shows information as it appears inside the ES index. 
  * `bin/tools/setup/*` : Simple perl scripts to create ES indexes, adjust as needed

You can follow these projects on the issues page, make contributions, report problems, etc. I mostly interact with myself for issue tracking, but would love for more people to be involved.
