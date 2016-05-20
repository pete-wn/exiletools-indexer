// Include various modules
var app = require('express')();
var http = require('http').Server(app);
var io = require('socket.io')(http);
var bodyParser = require('body-parser');
var _ = require('lodash');
var Kafka = require('no-kafka');
var consumer = new Kafka.SimpleConsumer();

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }));

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
var filter;

// Keep track of some stats as globals
var itemCount = 0;
var emittedItemCount = 0;
var connectedCount = 0;
var disconnectedCount = 0;

// use express to send a simple web page and get the query filter
// this is only for testing, ultimately we won't do this
app.get('/', function(req, res){
  res.sendFile(__dirname + '/index.html');
//  console.log('Got Filter: ' + req.query.filter);
  filter = req.query.filter;
});

// when a socket is created, add the filter information and socket
// to the appropriate arrays and objects, and make sure to delete
// them when the user disconnects
io.on('connection', function(socket){
  filterData[socket.id] = filter;
  socketIDs.push(socket.id);
  console.log('-->    CONNECTED: ' + socket.id + ' with Filter ' + filter);
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
        if (item.attributes.baseItemType == filterData[id]) {
          io.to(id).emit('item', item);
          emittedItemCount++;
        }
      });

    });
};
 
return consumer.init().then(function () {
    // Subscribe partitons 0 and 1 in a topic: 
    return consumer.subscribe('processed', 0, {time: Kafka.LATEST_OFFSET}, dataHandler);
});
