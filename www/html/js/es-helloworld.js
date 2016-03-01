// We define an EsConnector module that depends on the elasticsearch module.     
var EsConnector = angular.module('EsConnector', ['elasticsearch']);

// Create the es service from the esFactory
EsConnector.service('es', function (esFactory) {
  return esFactory({ host: 'http://apikey:DEVELOPMENT-Indexer@api.exiletools.com' });
});

EsConnector.controller('ExileToolsHelloWorld', function($scope, es) {
  // Set up the ES Search function
  es.search({
  index: 'index',
  // Query for the 100 most recently updated items of items updated in the last day
  body: {
    "sort": [
      {
        "shop.updated": {
          "order": "desc"
        }
      }
    ], 
    "query": {
      "filtered": {
        "filter": {
          "range": {
            "shop.updated": {
              "gte": "now-1d"
            }
          }
        }
      }
    },
    size:100
  }
  }).then(function (response) {
    $scope.Response = response;
  }, function (err) {
    console.trace(err.message);
  });

});
