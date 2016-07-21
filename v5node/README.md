This directory contains initial proof of concept code for portions of the
ExileTools Indexer v5, which will be written in node.js.

Nothing in this directory is intended to be actually run in production at
this time, it is 100% development, testing, and experimentation.

2016/07/21

This is an attempt to document the core features of a complete indexer rewrite using javascript.

# Indexer Core

1. Program to monitor official Stash Tab API and funnel data into Kafka
2. Program to monitor Kafka, process items, and add to Elasticsearch
+ ability to run debug indexing against specific item JSON data

## Supporting Tools

1. Removal of stale items from ES index
2. Creating of item base type data
3. Creating of unique item ID data

## Infrastructure

* Elasticsearch
* NodeJS 6+
* Apache Kafka
* Supervisor

# Indexer Core: [Incoming] Monitor GGG Stashtab API

Runs in an infinite loop. Controlled by supervisor. Single thread.

During each iteration:

1. Check to see if a next_change_id is tracked. Load it if so, otherwise start at 0.
2. Fetch the URL with next_change_id
3. Check for errors / problems, break and save current next_change_id, back off on iteration speed
4. Send each stash tab object to kafka partitions in round robin/random.
5. Count the number of stash tabs returned, if it is very low back off on the iteration speed
6. Save statistics to a CSV log file (note, this is currently done to an ES index)
7. Process new next_change_id, repeat

Optional: Store some significant amount of stats in memory and make this information available via a simple web request to the node service.

# Indexer Core: [Processing] Reformat GGG JSON to PWX JSON

This is the "meat" of the indexer and by far the most complicated portion.

Runs in an infinite loop controlled by supervisor. Multiple thread capable with each thread having access to its own Kafka partition for processing.

Works by constantly checking the Kafka partition for new stash tab data, and running a full processing iteration on every stash tab object. For each stash tab object, this includes:

1. Request all currently verified items matching that stash tab ID from the ES index (this should block)
2. Loop through each stash and process each item:
   a. Compare it to the current verified item data and mark it as new, updated, or modified as appropriate
   b. Process each item into ES JSON
   c. Remove data from historical object for each item
3. Any remaining items in the historical object should now be marked as GONE and updated appropriately
4. Proceed to the next stash

## Processing in More Detail

Processing items is very complex and includes a large number of steps. The core of these is as follows:

1. Populate derived attributes for the item, such as the updated/modified times, the item base type, etc.
2. Extract attributes for the item from the original (bad) JSON data, converting these into an indexable format. This includes populating mods and attributes.
3. Calculate analyzed stats for the item, such as extracting a price and currency from the note.
4. Calculate total and pseudo mods for the item.

Many of these steps are very complex, but all are required. The original JSON data sent to a client is *extremely poor* and is designed for displaying line by line information about an item, not for actual analysis of the item. Only a few attributes can be directly carried over.

During this reboot, we will begin with a line-by-line rewrite of the perl code and document from there.
