// This is an example socket-io client written for node.js
// Please review the requirements and information in the README to
// understand this.
//
// P.Waterman 2016-05-24

var ioc = require('socket.io-client');
var uuid = require('node-uuid');
// Connections REQUIRE a valid (and preferably unique) pwxid in order to be load balanced properly
var pwxid = uuid.v4();

// For remote / live testing, use the "real time stash" URL at rtstashapi.exiletools.com
// The localhost option is for internal testing/debugging
var socket = ioc.connect('http://rtstashapi.exiletools.com', {query: 'pwxid=' + pwxid});
//var socket = ioc.connect('http://localhost:6001', {query: 'pwxid=' + pwxid});

// Specify the filters here in a text format, we'll convert them to JSON. You can do this
// however you'd like in your own app obviously.
var filterText = '[ { "eq": { "attributes.league": "Standard", "attributes.baseItemType": "Jewelry", "attributes.rarity": "Rare", "shop.hasPrice": true }, "gt": { "modsPseudo.+# Total to maximum Life": 30 }, "lt": { "shop.chaosEquiv": 10 } }, { "eq": { "attributes.league": "Standard", "attributes.baseItemType": "Armour", "attributes.rarity": "Rare", "shop.hasPrice": true }, "gt": { "modsPseudo.+# Total to maximum Life": 30 }, "lt": { "shop.chaosEquiv": 10 } } ]';

// Convert the filter text to JSON
var filter = JSON.parse(filterText);

// On connect, verify the session and pwxid, then emit the filter object
// and notify locally of the filter sent for reference
socket.on("connect", function () {  
  var sessionid = socket.io.engine.id
  console.log("Connected with session id " + sessionid + " and pwxid " + pwxid);
  socket.emit('filter', filter);
  console.log("Sent Filter: " + JSON.stringify(filter));
});

// If the filter is invalid or something else goes wrong, you should see an error
// returned over this socket. The format will vary depending on where in the chain
// it happens. You should NOT attempt to re-submit the same filter, as this error
// almost always means the filter is bad.
socket.on('error', function(error) {
  console.log("Something went wrong! Received ERROR response:\n" + JSON.stringify(error, null, 2));
});

// Print out only the fullName from the received item JSON data when an item matches. This can
// and should be highly customized.
socket.on("item", function(item) {
  console.log("Received an item: " + item.info.fullName);
});

// Heartbeat messages are sent when the filter is accepted and roughly every 60 seconds
// afterwards, with the message in heartbeat.status - mostly this serves to keep
// the client aware that yes, items are being analyzed
socket.on("heartbeat", function(heartbeat) {
  console.log("Received a heartbeat: " + heartbeat.status);
});

// Just in case you can't connect properly, it's good to see why. The actual error
// doesn't seem to be very verbose though.
socket.on('connect_error', function(error){
    console.log('Connection Failed! ' + error);
});


