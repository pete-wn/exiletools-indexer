// We define an EsConnector module that depends on the elasticsearch module.     
var EsConnector = angular.module('EsConnector', ['elasticsearch','ui.bootstrap','ui.grid','ui.grid.autoResize','angularPromiseButtons','angular-cache','ngRoute','ui.select']).config( ['$routeProvider', function($routeProvider) {
$routeProvider
  .when('/:league/:unique', {
    templateUrl: 'uniqueReport.html',
    controller: 'uniqueReport',
  })
  .when('/:league', {
    templateUrl: 'uniqueChooser.html',
    controller: 'uniqueChooser',
    league: 'league'
  })
  .otherwise({
    redirectTo: '/'
  });
}]);


// Create the es service from the esFactory
EsConnector.service('es', function (esFactory) {
  return esFactory({ host: 'http://apikey:DEVELOPMENT-Indexer@api.exiletools.com' });
});

// We define an Angular controller that returns the server health
// Inputs: $scope and the 'es' service

EsConnector.controller('ServerHealthController', function($scope, es) {
    es.cluster.health(function (err, resp) {
        if (err) {
            $scope.data = err.message;
        } else {
            $scope.data = resp;
        }
    });
});

// We define an Angular controller that returns query results,
// Inputs: $scope and the 'es' service

EsConnector.controller('leagueChooser', function($scope, es, $location ) {

  var searchStart = new Date();
  // Get a list of leagues with uniques in them
  es.search({
    index: 'index',
    body: {
      "aggs" : {
        "leagues" : {
        "filter": { "term": { "attributes.rarity": "Unique" } },
          "aggs": {
            "uniquesInLeagues": {
              "terms": {
                "field": "attributes.league",
                "size": 10,
                "execution_hint": "global_ordinals_low_cardinality"
              }
            }
          }
        }
      },
      size:0 
    }
  }).then(function (response) {
    var searchEnd = new Date();
    console.log("Search executed in " + (searchEnd - searchStart) + "ms");
    // Create an information Array
    LeagueStats = new Object();
  
    // Loop through all the ItemsInLeagues buckets
    response.aggregations.leagues.uniquesInLeagues.buckets.forEach(function (item, index, array) {
      // Add the total count information and league name
      LeagueStats[item.key] = item.doc_count;
    });
    // Return the array as LeagueStats to Angular
    $scope.LeagueStats = LeagueStats;

  }, function (err) {
    console.trace(err.message);
  });

  $scope.selectLeague = function (league) {
    $location.path(league);
    console.log(league + " league selected");
    return;
  }

});

EsConnector.controller('uniqueChooser', function($scope, $routeParams, es, $location) {
  $scope.league = $routeParams.league;
  console.log("uniqueChooser: Generating list of items in " + $scope.league);
  var searchStart = new Date();

  // Start loading icon
  $("#loader").html('<div style="width:600px" class="alert alert-warning" role="alert"><i class="fa fa-gear fa-spin" style="font-size:500%"></i> Populating unique item list for ' + $scope.league + '...</div>');

  // Get a list of uniques available in this league
  es.search({
    index: 'index',
    body: {
      "aggs" : {
        "leagues" : {
        "filter": {
          "bool": {
            "must" : [
              { "term" : { "attributes.rarity" : "Unique" } },
              { "term" : { "attributes.identified" : true } },
              { "term" : { "attributes.league" : $scope.league } }
            ]
          }
        },
          "aggs": {
            "uniqueNames": {
              "terms": {
                "field": "info.fullName",
                "size": 1000
              }
            }
          }
        }
      },
      size:0
    }
  }).then(function (response) {
    var searchEnd = new Date();
    console.log("Search executed in " + (searchEnd - searchStart) + "ms");


    // Define the Uniques array
    var Uniques = new Array();

    // Loop through all the unique names buckets
    response.aggregations.leagues.uniqueNames.buckets.forEach(function (item, index, array) {
//      Uniques.push(item.key + " (" + item.doc_count + ")");
      Uniques.push(item.key);
    });

    // Sort it
    Uniques.sort();

    // Give it to scope
    $scope.Uniques = Uniques;

    // Clear loader
    $("#loader").html('');

  }, function (err) {
    console.trace(err.message);
  });

  $scope.selectUnique = function (unique) {
    $location.path($scope.league + "/" + unique);
    console.log(unique + " selected");
    return;
  }

  return true;
});

EsConnector.controller('uniqueReport', function($scope, $routeParams, es) {
  $scope.league = $routeParams.league;
  $scope.unique = $routeParams.unique;
  console.log("Unique report for " + $scope.unique + " in " + $scope.league);

  // Start loading icon
  $("#loader").html('<div style="width:600px" class="alert alert-warning" role="alert"><i class="fa fa-gear fa-spin" style="font-size:500%"></i> Creating report for ' + $scope.unique + " in " + $scope.league + '...</div>');

  // Initial large query
  es.search({
    index: 'index',
    body: {
  "query": {
    "filtered": {
      "filter": {
        "bool": {
          "must" : [
            { "term" : { "attributes.rarity" : "Unique" } },
            { "term" : { "attributes.league" : $scope.league } },
            { "term" : { "info.fullName" : $scope.unique } }
          ]
        }
      }
    }
  },
  "aggs": {
    "verified": {
      "terms": {
        "field": "shop.verified",
        "size": 10
      }
    },    
    "icons": {
      "terms": {
        "field": "info.icon"
      }
    },
    "baseItemType": {
      "terms": {
        "field": "attributes.baseItemType"
      }
    },
    "itemType": {
      "terms": {
        "field": "attributes.itemType"
      }
    },
    "equipType": {
      "terms": {
        "field": "attributes.equipType"
      }
    },
    "corrupted": {
      "terms": {
        "field": "attributes.corrupted"
      }
    },    
    "histoAdded": {
      "date_histogram": {
        "field": "shop.added",
        "interval": "day"
      }
    },
    "histoUpdated": {
      "date_histogram": {
        "field": "shop.updated",
        "interval": "day"
      }
    }
  },
  size:0
    }
  }).then(function (response) {
    // stuff
    var Icons = new Array();
    response.aggregations.icons.buckets.forEach(function (item, index, array) {
      Icons.push(item.key);
    });
    $scope.Icons = Icons;

    // Set some other variables from the data
    $scope.baseItemType = response.aggregations.baseItemType.buckets[0].key
    $scope.itemType = response.aggregations.itemType.buckets[0].key
    $scope.equipType = response.aggregations.equipType.buckets[0].key

    // Iterate through verified 
    $scope.verified = new Object();
    response.aggregations.verified.buckets.forEach(function (item, index, array) {
      $scope.verified[item.key] = item.doc_count;

    });

  $scope.readyReport = true;
  // Clear loader
  $("#loader").html('');

  }, function (err) {
    console.trace(err.message);
  });











  return true;
});

