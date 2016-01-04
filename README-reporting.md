# exiletools-reporting

A web front end for reporting on Path of Exile Shop Forum Indexing using the ExileTools indexer.

The current release is available for viewing live here: [http://exiletools.com/dashboard](http:/exiletools.com/dashboard)

## Goals (WIP)

The idea behind this project is three-fold:

1. Report on the current health and status of the indexer

2. Provide insights into the economy as indicated by statistics within the indexer

3. Showcase the ease of drawing out interesting statistics on the Path of Exile economy by using ElasticSearch queries against the ExileTools index to encourage community analysis. 

Additionally, I will be using only public API data via javascript calls, adding additional back-end indexes and data as necessary to support these. I want to continue to provide a completely open system for analyzing the economy without creating back-end tools. As part of this project, numerous improvements will be made to the [ExileTools Indexer Project](https://github.com/trackpete/exiletools-indexer) to support open data.

This entire project will also serve as a learning experience for AngularJS and Javascript in general, as I have never used these systems before.

## v1 Milestone Features:

The following features are targeted for the v1 Milestone Release:

1. General "headline" index statistics, such as the number of shops/sellers, number of updates, total items, etc.

2. League specific index statistics on total of items, including a breakdown by current Verified status

3. Graphs showing indexing activity, including shop pages fetched, bumped threads, new threads, and MB of data transferred.

## v2 Milestone Features:

The following features are planned for the second release, showcasing additional data and reports:

1. Specific item based statistics, including: # of items by baseItemType, most popular mods, most expensive mods, breakdowns by rarity

2. Unique item statistics, including: # of items by fullName, # items added/GONE (including percentages for "desirability"), price history graphs, etc.

3. Quick reference charts including: prices of map per tier, prices of unique items, prices of certain items with mods (TBD: for example, jewels with +% life?)

## Contributions / Issues / Pull Requests / Forks / etc.

I will gladly accept contributions and link to forks, and I'd love suggestions via Issues. Anyone experienced with AngularJS or Javascript in general will likely look at my code and be able to suggest huge improvements, since I literally had no idea what I was doing when I started this project.

If you'd like to add graphs/reports, enhance the current ones, or just make suggestions for a type of report I should add or an improvement I could make to my code, please do so!

   -Pete (pete@pwx.me)
