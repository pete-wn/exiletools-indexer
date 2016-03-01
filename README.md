# ExileTools Indexer v3+

This project contains the open source indexer back-end used by ExileTools for its free ElasticSearch API service, a searchable index of all items for sale (or recently for sale) by players of Path of Exile using the Stash Tab API service from Grinding Gear Games.

You may use this code to run your own private or public index, contribute to this code, or simply learn from it. My only request is that you avoid trying to recognize revenue via direct use of my code.

# Do you need to run this? ExileTools makes the data available publicly for free!

If all you're looking for is direct access to an index, check out the free ElasticSearch API service by ExileTools - no need to run your own!

http://api.exiletools.com/info/indexer.html

You can get up and running in literally seconds with Elastic Search queries against live Stash Tab data. For hundreds of example queries to get you started, check out http://gists.github.com/trackpete or look at some of the AngularJS code in the front ends included in this project! The indexer page above also contains very detailed explanations of the Elastic Search mapping.

# What the Stash Tab Indexer Does

When a player modifies any item in their public stash tabs the stash tab is pushed out in a river based JSON API service. The ExileTools Indexer River Watch service runs as a daemon that constantly monitors this river. Changes are processed in near-realtime, with item updates showing up in ElasticSearch typically within 10s of being pushed to the Stash Tab API.

The default item JSON data is poorly optimized for searching, thus the majority of the processing that takes place in the ExileTools Indexer is a complete re-building of the item from the ground up using. This building of a new item JSON structure translates better into ElasticSearch, and consists of the following general changes:

* The item type is detected from the name and stats, including where it can be equipped and what it is
* Mods are detected and converted into searchable values
* Psuedo and Total mods are calculated
* Properties of the item are broken down into easier to index fields
* Some additional properties are calculated (i.e. DPS)
* Price is made searchable and indexed with a fixed-rate chaosEquiv value added for sorting
* Socket information is converted into an easier to use form
* All general item information is broken out into easily indexed and searched fields
* General shop information is added to the item, such as when it was added, if it's still available, when it was last modified, etc.

This mapping is documented in detail on the Index JSON Structure page at ExileTools.

# Requirements

v3 includes full support for GGG's new Stash Tab API service, and as such completely deprecates and removes the entire shop forum crawling system. There is no longer any need for MariaDB/MySQL as all data is maintained directly in ElasticSearch.

As of this writing, you will need the following to run this Indexer on your own server:

1. ElasticSearch v2.1+
  * You will need an item index and a stats index. Simple example scripts to create this can be found in `setup`
2. Perl v5.10+
  * You will need a number of perl modules to run the various perl programs. Check the `use` lines throughout the scripts, perl will notify you if you are missing anything as you run stuff
3. A decent server and internet pipe
  * I would recommend at least a quad core server with 16GB of RAM and an SSD on a connection that can handle 20-50GB+/mo of data transfer

To install and get it up and running, you will need to modify the sample config file with your ElasticSearch Host information, create the appropriate indexes, then just start River Watch!

## Optional: Supervisord

Instead of just running the River Watch program in the foreground, you can run it in the background using Supervisord (on a linux system), which will
automatically manage restarting/etc. attempts on critical failures and ensure log information is throw into a log file. I've included an example config file for supervisord called `supervisord.poe-watch-stash-tab-river.conf` which you can modify with the appropriate paths.

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

2. `ladder-skilltrees` : Tools to store the top player's skilltree information in an ES Index

3. `tools` : Various supporting tools, usually intended to be run from the root directory
  * `tools/watch-modified-items.pl` : Dumps information about recently modified items in the ES index to confirm items are being processed. Unlike log output from River Watch, this shows information as it appears inside the ES index. 
  * `tools/setup/*` : Simple perl scripts to create ES indexes, adjust as needed

You can follow these projects on the issues page, make contributions, report problems, etc. I mostly interact with myself for issue tracking, but would love for more people to be involved.
