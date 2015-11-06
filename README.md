# poe-json-to-elasticsearch
Re-formats stock item JSON data from pathofexile.com to a better format for ElasticSearch

This script is a subroutine used by the ExileTools indexer to modify JSON data into a format that is far superior for indexing in ElasticSearch. The goal is to take the messy default item JSON data (which is intended to show a pop-up on a web page) and turn it into a logical format that clearly shows the items stats in an easily referenceable manner.

This script is written in Perl, and may at times seem very clumsy. Many of the things you will see happening in this script were added on the fly as I learned about various things, and Perl itself leads to very different ways of doing things depending on the user. I'm mostly putting this on github to keep track of improvements and changes - you may be able to use this script yourself, but it's probably pretty messy to anyone else.
