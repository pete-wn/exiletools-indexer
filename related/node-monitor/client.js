var ioc = require('socket.io-client');
var uuid = require('node-uuid');
var pwxid = uuid.v4();

//var socket = ioc.connect('http://livestashtest.exiletools.com', {query: 'pwxid=' + pwxid});
var socket = ioc.connect('http://localhost:8777');


var filterText = '[ { "eq": { "attributes.baseItemType": "Jewelry", "attributes.rarity": "Rare", "shop.hasPrice": true }, "gt": { "modsPseudo.+# Total to maximum Life": 30 }, "lt": { "shop.chaosEquiv": 10 } }, { "eq": { "attributes.baseItemType": "Armour", "attributes.rarity": "Rare", "shop.hasPrice": true }, "gt": { "modsPseudo.+# Total to maximum Life": 30 }, "lt": { "shop.chaosEquiv": 10 } }, { "eq": { "attributes.baseItemType": "Armour", "attributes.rarity": "Rare", "shop.hasPrice": true }, "gt": { "modsPseudo.+# Total to maximum Life": 30 }, "lt": { "shop.chaosEquiv": 10 } }, { "eq": { "attributes.baseItemType": "Armour", "attributes.rarity": "Rare", "shop.hasPrice": true }, "gt": { "modsPseudo.+# Total to maximum Life": 30 }, "lt": { "shop.chaosEquiv": 10 } }, { "eq": { "attributes.baseItemType": "Armour", "attributes.rarity": "Rare", "shop.hasPrice": true }, "gt": { "modsPseudo.+# Total to maximum Life": 30 }, "lt": { "shop.chaosEquiv": 10 } }, { "eq": { "attributes.baseItemType": "Armour", "attributes.rarity": "Rare", "shop.hasPrice": true }, "gt": { "modsPseudo.+# Total to maximum Life": 30 }, "lt": { "shop.chaosEquiv": 10 } }, { "eq": { "attributes.baseItemType": "Armour", "attributes.rarity": "Rare", "shop.hasPrice": true }, "gt": { "modsPseudo.+# Total to maximum Life": 30 }, "lt": { "shop.chaosEquiv": 10 } }, { "eq": { "attributes.baseItemType": "Armour", "attributes.rarity": "Rare", "shop.hasPrice": true }, "gt": { "modsPseudo.+# Total to maximum Life": 30 }, "lt": { "shop.chaosEquiv": 10 } }, { "eq": { "attributes.baseItemType": "Armour", "attributes.rarity": "Rare", "shop.hasPrice": true }, "gt": { "modsPseudo.+# Total to maximum Life": 30 }, "lt": { "shop.chaosEquiv": 10 } }, { "eq": { "attributes.baseItemType": "Armour", "attributes.rarity": "Rare", "shop.hasPrice": true }, "gt": { "modsPseudo.+# Total to maximum Life": 30 }, "lt": { "shop.chaosEquiv": 10 } } ]';

var filter = JSON.parse(filterText);




socket.on("connect", function () {  
  var sessionid = socket.io.engine.id
  console.log("Connected with session id " + sessionid);
  socket.emit('filter', filter);
  console.log("Sent Filter");
});

socket.on('error', console.error.bind(console));

socket.on("item", function(item) {
  console.log("Received an item: " + item.info.fullName);
});


