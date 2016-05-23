// Include various modules
var app = require('http').createServer(handler)
var io = require('socket.io')(app);
var bodyParser = require('body-parser');
var _ = require('lodash');
var Kafka = require('no-kafka');
var consumer = new Kafka.SimpleConsumer();
var dt = require("dotty");
var prettyHrtime = require('pretty-hrtime');

// filterData will contain an object with various filters to search against
// It is updated by each new connection. This is really weird and maybe inefficient.
// I doubt it will scale to thousands of users but let's see eh?
var filterData = new Object;

// An array to keep track of socket id's, because socket.io only does this
// via an object
var socketIDs = new Array;

// Keep track of some stats as globals
var itemCount = 0;
var emittedItemCount = 0;
var connectedCount = 0;
var disconnectedCount = 0;
var itemProcessTime = new Array;

// socket.io listens on argv2
app.listen(process.argv[2]);

// this should ultimately just send a page with information, ignore the
// current testing leftovers, we've moved to command line testing
function handler (req, res) {
  fs.readFile(__dirname + '/index.html',
  function (err, data) {
    if (err) {
      res.writeHead(500);
      return res.end('Error loading index.html');
    }

    res.writeHead(200);
    res.end(data);
  });
}

// Receive the socket connection
io.on('connection', function(socket){
  console.log('-->    CONNECTED: ' + socket.id);
  // Add the socket ID for the array to check for filters - we should probably do this
  // after receiving a filter if the socketID isn't already in the array.
  socketIDs.push(socket.id);
  connectedCount++; 

  // If a filter is sent, update filterData with the filter
  // we should probably add a response
  socket.on('filter', function (filter) {
    console.log('--> RECVD FILTER: ' + socket.id + ' ' + JSON.stringify(filter));
    filterData[socket.id] = filter;
  });


  // If the socket disconnects, remove the information from the filterData object
  // and the socketIDs array
  socket.on("disconnect", function () {
    console.log('<-- DISCONNECTED: ' + socket.id);
    delete filterData[socket.id];
    socketIDs = _.without(socketIDs, socket.id);
    disconnectedCount++;
  });
});

// This is a simple timer to print out some statistics every minute to the console log
setInterval(function() {
  var time = new Date();
  console.log(time + " Active Clients Connected: " + socketIDs.length);
  console.log(time + " " + itemCount + " Items Added/Modified in this interval (" + itemCount / 60 + " items/s)");
  console.log(time + " " + emittedItemCount + " Items Emitted to Clients in this interval");
  console.log(time + " " + connectedCount + " Clients Connected | " + disconnectedCount + " Disconnected in this interval");
  console.log(time + " Average Item Processing Time: " + _.mean(itemProcessTime) + " nanoseconds");

  itemCount = 0;
  connectedCount = 0;
  disconnectedCount = 0;
  emittedItemCount = 0;
  itemProcessTime = [];

}, 60000);

// This is the active part of the server that constantly consumes the kafka processed queue
// and attempts to emit to the sockets that want the information it has based on their
// filters 
var dataHandler = function (messageSet, topic, partition) {
    messageSet.forEach(function (m) {
      // turn this into a JSON object named item so we can reference it
      var item = JSON.parse(m.message.value.toString('utf8'));
      itemCount++;

      // Measure the time it takes to process the item by iteration/etc.
      var itemProcessStart = process.hrtime();

      // This part probably could be done way better. My thought was, on each
      // item, iterate through every socket to see if they have a filter that
      // matches this item. At some point we're going to spend more time
      // iterating the array and comparing than we are keeping up with the stream.
      socketIDs.forEach(function(id) {
        _.forEach(filterData[id], function(thisFilter) {
          var pass = 1;
          _.forEach(thisFilter.eq, function checkCore (value, key) {
            if (dt.get(item,key) == thisFilter.eq[key]) {
              // console.log("PASS: " + item.info.fullName + " " + key + " of " + dt.get(item,key) + " matches " + thisFilter.eq[key]);
              pass = 1;
            } else {
              pass = 0;
              return false;
            }
          });
          // really need to find a better way to do this
          if (pass == 1) {
            _.forEach(thisFilter.gt, function checkGt(value, key) {
              if (dt.get(item,key) > thisFilter.gt[key]) {
                // console.log("PASS: " + item.info.fullName + " " + key + " of " + dt.get(item,key) + " is greater than " + thisFilter.gt[key]);
                pass = 1;
              } else {
                pass = 0;
                return false;
              }
            });
          }
          if (pass == 1) {
            _.forEach(thisFilter.lt, function checkGt(value, key) {
              if (dt.get(item,key) < thisFilter.lt[key]) {
                // console.log("PASS: " + item.info.fullName + " " + key + " of " + dt.get(item,key) + " is less than " + thisFilter.lt[key]);
                pass = 1;
              } else {
                pass = 0;
                return false;
              }
            });
          }

          if (pass == 1) {
            //io.to(id).emit('item', item);
            emittedItemCount++;
          }
        });
      });

      var itemProcessEnd = process.hrtime(itemProcessStart);
      itemProcessTime.push(itemProcessEnd[0] * 1e9 + itemProcessEnd[1]);

    });
};
 
return consumer.init().then(function () {
    // Subscribe partitons 0 and 1 in a topic: 
//    return consumer.subscribe('processed', 0, {time: Kafka.LATEST_OFFSET, maxBytes: 20971520, maxWaitTime: 20}, dataHandler);
    return consumer.subscribe('processed', 0, {time: Kafka.EARLIEST_OFFSET, maxBytes: 20971520, maxWaitTime: 20}, dataHandler);
//    return consumer.subscribe('processed', 0, {time: Kafka.EARLIEST_OFFSET}, dataHandler);
});
