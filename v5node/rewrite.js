// This is an initial proof of concept.
// Eventually this program will be built into a full JSON re-formatted for Path of Exile
// Item Documents
//
// Right now, it uses Kafka to pull *sample* data from the live Indexer partition
// At some point, we'll have to change this to test cases instead. This is just
// the fastest way to get up and running.

// Initial variables
var _ = require('lodash');
var Kafka = require('no-kafka');
var consumer = new Kafka.SimpleConsumer();
var dt = require("dotty");
var prettyHrtime = require('pretty-hrtime');

// Read in JSON data files
var frameTypeToRarity = require('./data/frameType-to-Rarity.json');

// Local settings for short circuiting
var processedCount = 0, maxToProcess = 2;

// Iterate the Kafka stash data
var dataHandler = function (messageSet, topic, partition) {
  var timeProcessStart = process.hrtime(); // Set a timer
  messageSet.forEach(function (m) {
    processedCount++;
    if (processedCount > maxToProcess) {
      var timeProcessEnd = process.hrtime(timeProcessStart);
      var prettyTime = prettyHrtime(timeProcessEnd);
      console.log(maxToProcess + " stashes processed in " + prettyTime);
      process.exit(0);
    }
    // turn this stash into a JSON object named item so we can reference it
    var stash = JSON.parse(m.message.value.toString('utf8'));
//    console.log("This Stash: " + stash.stash);  

    // Iterate through each item in the stash
    stash.items.forEach(function (item) {
      processItem(item,stash);
    });
  });
};

// This is the core function that actually processes item JSON data
function processItem(item,stash) {
  var e = new Object(); // This represents the Elasticsearch formatted JSON data. On a separate line for clarity.

  e.uuid = item.id;

  // Begin by setting fixed data from item, note all items at this point are verified as YES
  e.shop = { sellerAccount:stash.accountName, lastCharacterName:stash.lastCharacterName, note:item.note, verified:"YES" };
  e.shop.stash = { stashID:stash.id, stashName:stash.stash, inventoryID:item.inventoryId, xLocation:item.x, yLocation:item.y };
  e.attributes = { inventoryWidth:item.w, intentoryHeight:item.h, league:item.league, identified:item.identified, corrupted:item.corrupted, ilvl:item.ilvl, frameType:item.frameType, rarity:frameTypeToRarity[item.frameType] };
  e.info = { name:item.name }; // note we set an empty name and typeLine if they don't exist, that's ok, these fields confuse people

  // These are sections that we only want to set if it exists in the original data
  if (item.support) { e.attributes.support = item.support };
  if (item.talismanTier > 0) { e.attributes.talismanTier = item.talismanTier };

  // Some fields that we populate need to be cleaned up a bit while we set them
  e.info.icon = item.icon.replace(/\?.*$/, '');  // Remove junk from URL
  e.info.typeLine = item.typeLine.replace(/^(Superior |\s+)/, '');  // Remove leading Superior or whitespace from typeLine

  // Setting the item's full name is a bit confusing because we have two fields
  // that may or may not exist and may comprise bits of the name, so I'm using
  // an if statement to join them to avoid unecessary spaces
  if (item.name && item.typeLine) {
    e.info.fullName = (item.name + " " + item.typeLine);
  } else if (item.name) {
    e.info.fullName = item.name;
  } else if (item.typeLine) {
    e.info.fullName = item.typeLine;
  }





  console.log(JSON.stringify(e, null, ' '));
};


// KAFKA DATA HANDLER FUNCTION - must be at the end!

// Grab some data from Kafka
return consumer.init().then(function () {
  return consumer.subscribe('incoming', 0, {time: Kafka.EARLIEST_OFFSET, maxBytes: 252600000, maxWaitTime: 20}, dataHandler);
});

