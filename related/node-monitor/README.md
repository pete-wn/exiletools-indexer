# Overview

This directory contains the server code and example client code for the
ExileTools Real Time Stash API service.

In short, as items from the Official Stash Tab API are consumed by the
ExileTools Indexer, any item that is detected as being Added or Modified
is added to a special Kafka topic on the indexing master.

The Real Time Stash API server nodes run constantly consuming this topic
that contains modified items. Every item is compared against an internal
object that contains a bunch of JSON filters sent by API clients, and
if an object matches the filter that object is sent to the API client via
SocketIO. 

The result is that a Real Time Stash API client will typically receive a
push notification via web sockets in less than five seconds after an item
is published by the Official Stash Tab API. In the interim, that client can
simply sit idle waiting for new data, and does not need to do any active
searches.

# Client Methodology

Clients can be written using any system that supports SocketIO:

http://socket.io

The git repo you are looking at now includes a file called `client.js` 
which includes an example command line node.js client.

It works like this:

1. The client creates a javascript object that contains JSON data with an
   array of filters.
2. The client connects to the public Real Time Stash API service and
   establishes a socket.io connection. This connection *must* include
   the query parameter `pwxid` with a (preferably) unique randomly generated
   id. This id will be used by the ExileTools Load Balancer to ensure all
   traffic is passed to the appropriate backend node - without it, you 
   will receive all sorts of errors.
3. Once connected, the client sends the filter object to the server. The
   server verifies the filter object, then adds it to a queue of filters to
   analyze on each item.
4. Any time an item is added, the server compares it to the filters and 
   sends any item that matches it out to the appropriate client as a JSON
   object named `item`
5. The client can do whatever it wants with this JSON object to present
   information to the user. It contains the full stats of the item as seen
   in the ExileTools Public Elasticsearch Index.
6. Approximately every 60s, the server will also send a `heartbeat` object
   to all clients that contains a simple message about how many items have
   been added/modified recently. This is to assure clients that the stream
   is active even when they are not receiving matching items.

# Important Things

* The JSON filter must follow a very specific format. This is detailed below. 
* Each client can have a maximum of 20 filters active.
* The filters can be updated at any time by sending a new filter object.
* Every item in a filter *must specify a league.* Filters without will be rejected.
* The format of filter terms follows the dot notation of the Elasticsearch objects

# Filters

The filter format is very simple. It should be a JSON array of objects. Each
object within the filter set will be a single filter. This filter can include
three objects:

1. `eq` : This will do exact value matches. 
2. `gt` : This will do greater than range matches on values.
3. `lt` : This will do less than range matches on values.

The `gt` and `lt` objects are optional on each filter, however the `eq` is required
because you *must* specify a league.

The following is a *bare minimum* filter object which sends one filter requesting
all items in the Standard league:

```
[
  {
    "eq" : {
      "attributes.league": "Standard"
    }
  }
]
```

(don't use that except for initial testing though, because you aren't supposed to
consume everything)

# Filter Examples

## Basic Item Matching

This filter will return all items in Standard that are Jewelry items with a Rare rarity that have a price set as long as they have greater than 30 Total to maximum life (pseudo mod) and have a chaos equivalent price of less than 10 chaos:

```
[
  {
    "eq": {
      "attributes.league": "Standard",
      "attributes.baseItemType": "Jewelry",
      "attributes.rarity": "Rare",
      "shop.hasPrice": true
    },
    "gt": {
      "modsPseudo.+# Total to maximum Life": 30
    },
    "lt": {
      "shop.chaosEquiv": 10
    }
  }
]
```

This filter will return all Tabula Rasa items posted to Standard that have a price of less than 5 chaos equivalent:

```
[
  {
    "eq": {
      "attributes.league": "Standard",
      "info.fullName": "Tabula Rasa Simple Robe",                                                                                                               
      "shop.hasPrice": true
    },
    "lt": {
      "shop.chaosEquiv": 5
    }
  }
]
```
## Multiple Filters

Filters can be stacked simply by adding items together in an array. To apply both of the example searches shown above
on every item:

```
[
  {
    "eq": {
      "attributes.league": "Standard",
      "attributes.baseItemType": "Jewelry",
      "attributes.rarity": "Rare",                                                                                                               
      "shop.hasPrice": true
    },
    "gt": {
      "modsPseudo.+# Total to maximum Life": 30
    },
    "lt": {
      "shop.chaosEquiv": 10
    }
  },
  { 
    "eq": {
      "attributes.league": "Standard",
      "info.fullName": "Tabula Rasa Simple Robe",
      "shop.hasPrice": true
    },
    "lt": {
      "shop.chaosEquiv": 5
    }
  }
]
```
