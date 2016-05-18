This directory contains the ExileTools Indexer Core.

There are two main pieces of this, designed to be run asynchronously:

1. incoming-monitor-ggg-stashtab-api.pl : Monitors the Stash Tab API and pushes updates into Kafka partitions for processing
2. process-reformat-ggg-to-pwx.pl : Monitors the Kafka partitions and reforms the JSON data for indexing into ElasticSearch (and bulk indexes it)


