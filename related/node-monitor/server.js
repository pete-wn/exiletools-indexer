// Include various modules
var express = require('express');
var app = express();
var http = require('http').Server(app);
var io = require('socket.io')(http);
var bodyParser = require('body-parser');
var _ = require('lodash');
var Kafka = require('no-kafka');
var consumer = new Kafka.SimpleConsumer();
var dt = require("dotty");

app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use('/public', express.static(__dirname + '/public'));

// filterData will contain an object with various filters to search against
// It is updated by each new connection. This is really weird and maybe inefficient.
// I doubt it will scale to thousands of users but let's see eh?
var filterData = new Object;

// An array to keep track of socket id's, because socket.io only does this
// via an object
var socketIDs = new Array;

// Make sure the filter variable is global so we can see it from get
// I expect I will need to optimize this because if two users connect
// in the same millisecond with different filters, what happens?
var filter = new Array;

// Keep track of some stats as globals
var itemCount = 0;
var emittedItemCount = 0;
var connectedCount = 0;
var disconnectedCount = 0;

// Retrieve the GET data and send a simple output web page
// we'll have to do this slightly differently for applications, this is
// still POC phase
app.post('/', function(req, res){
  res.sendFile(__dirname + '/index.html');
  filter = JSON.parse(req.body.filter);

});

// when a socket is created, add the filter information and socket
// to the appropriate arrays and objects, and make sure to delete
// them when the user disconnects
io.on('connection', function(socket){
  socketIDs.push(socket.id);
  filterData[socket.id] = filter;


  console.log('-->    CONNECTED: ' + socket.id + ' with Filter ' + JSON.stringify(filter));
  connectedCount++; 
  socket.on("disconnect", function () {
    console.log('<-- DISCONNECTED: ' + socket.id);
    delete filterData[socket.id];
    socketIDs = _.without(socketIDs, socket.id);
    disconnectedCount++;
  });
});

// express web server
http.listen(8777, function(){
  console.log('listening on *:8777');
});

// This is a simple timer to print out some statistics every minute to the console log
setInterval(function() {
  var time = new Date();
  console.log(time + " Active Clients Connected: " + socketIDs.length);
  console.log(time + " " + itemCount + " Items Added/Modified in this interval");
  console.log(time + " " + emittedItemCount + " Items Emitted to Clients in this interval");
  console.log(time + " " + connectedCount + " Clients Connected | " + disconnectedCount + " Disconnected in this interval");
  itemCount = 0;
  connectedCount = 0;
  disconnectedCount = 0;
  emittedItemCount = 0;

}, 60000);

// This is the active part of the server that constantly consumes the kafka processed queue
// and attempts to emit to the sockets that want the information it has based on their
// filters 
var dataHandler = function (messageSet, topic, partition) {
    messageSet.forEach(function (m) {
      // turn this into a JSON object named item so we can reference it
      var item = JSON.parse(m.message.value.toString('utf8'));
      itemCount++;

      // This part probably could be done way better. My thought was, on each
      // item, iterate through every socket to see if they have a filter that
      // matches this item. At some point we're going to spend more time
      // iterating the array and comparing than we are keeping up with the stream.
      socketIDs.forEach(function(id) {
        var pass = 1;
        _.forEach(filterData[id], function(thisFilter) {
          _.forEach(thisFilter.core, function checkCore (value, key) {
            if (dt.get(item,key) == thisFilter.core[key]) {
              console.log("PASS: " + item.info.fullName + " " + key + " of " + dt.get(item,key) + " matches " + thisFilter.core[key]);
              pass = 1;
            } else {
              pass = 0;
//              console.log("this item failed a check, breaking");
              return false;
            }
          });
          // Need to go back and see if I can return true if the foreach completes, but this
          // works for now
          if (pass == 0) {
//            console.log("DEBUG: This item failed a check, returning");
            return false;
          }
          _.forEach(thisFilter.gt, function checkGt(value, key) {
            if (dt.get(item,key) > thisFilter.gt[key]) {
              console.log("PASS: " + item.info.fullName + " " + key + " of " + dt.get(item,key) + " is greater than " + thisFilter.gt[key]);
              pass = 1;
            } else {
              pass = 0;
//              console.log("this item failed a check, breaking");
              return false;
            }
          });
          // Need to go back and see if I can return true if the foreach completes, but this
          // works for now
          if (pass == 0) {
//            console.log("DEBUG: This item failed a check, returning");
            return false;
          }
          _.forEach(thisFilter.lt, function checkGt(value, key) {
            if (dt.get(item,key) < thisFilter.lt[key]) {
              console.log("PASS: " + item.info.fullName + " " + key + " of " + dt.get(item,key) + " is less than " + thisFilter.lt[key]);
              pass = 1;
            } else {
              pass = 0;
//              console.log("this item failed a check, breaking");
              return false;
            }
          });

          if (pass == 1) {
            io.to(id).emit('item', item);
            emittedItemCount++;
          }
        });
      });

    });
};
 
return consumer.init().then(function () {
    // Subscribe partitons 0 and 1 in a topic: 
    return consumer.subscribe('processed', 0, {time: Kafka.LATEST_OFFSET}, dataHandler);
});
