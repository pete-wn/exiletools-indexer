// We define an EsConnector module that depends on the elasticsearch module.     
var EsConnector = angular.module('EsConnector', ['elasticsearch','ui.bootstrap','ui.grid','ui.grid.autoResize','angularPromiseButtons','angular-cache','ngRoute','ui.select','ngStorage']).config( ['$routeProvider', function($routeProvider) {
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

EsConnector.controller('leagueChooser', function($scope, es, $location, $localStorage, $sessionStorage ) {

  // Check to see if we have the LeagueStats in localStorage already and if it's not too old (10min)
  if ($localStorage.LeagueStats && (new Date() - $localStorage.AgeLeagueStats) < 600000) {
    console.log("LeagueStats are in local storage as of " + $localStorage.AgeLeagueStats + ", using cached data");
    $scope.LeagueStats = $localStorage.LeagueStats;
  } else {
    console.log("LeagueStats aren't in local storage or are out of date, performing new search.");
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
  
      // Set this in local storage
      $localStorage.LeagueStats = LeagueStats;
  
      // Set the time in local storage
      $localStorage.AgeLeagueStats = new Date().valueOf();
  
    }, function (err) {
      console.trace(err.message);
    });
  }

  $scope.selectLeague = function (league) {
    $location.path(league);
    console.log(league + " league selected");
    return;
  }

});

EsConnector.controller('uniqueChooser', function($scope, $routeParams, es, $location, $localStorage, $sessionStorage) {
  $scope.league = $routeParams.league;
  
  // Check to see if we have list of unique items for this league in local storage
  if ($localStorage[$scope.league] && $localStorage[$scope.league].Uniques && (new Date() - $localStorage[$scope.league].AgeUniques) < 600000) {
    console.log("Uniques for " + $scope.league + " are in Local Storage as of " + $localStorage[$scope.league].AgeUniques + ", using cached data");

    // Sort it
    UniquesSorted = $localStorage[$scope.league].Uniques.slice().sort();

    // Give it to scope
    $scope.Uniques = UniquesSorted;
  } else {
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
      // Give it to localStorage
      $localStorage[$scope.league] = new Object();
      $localStorage[$scope.league].Uniques = Uniques;
      $localStorage[$scope.league].UniquesUnsort = Uniques;
      $localStorage[$scope.league].AgeUniques = new Date().valueOf();
  
      // Sort it
      UniquesSorted = Uniques.slice().sort();

      // Give it to scope
      $scope.Uniques = UniquesSorted;

      // Clear loader
      $("#loader").html('');

    }, function (err) {
      console.trace(err.message);
    });
  }

  $scope.selectUnique = function (unique) {
    $location.path($scope.league + "/" + unique);
    console.log(unique + " selected");
    return;
  }

  return true;
});

EsConnector.controller('uniqueReport', function($scope, $routeParams, es, $localStorage, $sessionStorage) {
  $scope.league = $routeParams.league;
  $scope.unique = $routeParams.unique;
  console.log("Unique report for " + $scope.unique + " in " + $scope.league);

  // Start loading icon
  $("#loader").html('<div style="width:600px" class="alert alert-warning" role="alert"><i class="fa fa-gear fa-spin" style="font-size:500%"></i> Creating report for ' + $scope.unique + " in " + $scope.league + '...</div>');

  // Get the item rank
  var count = 0;
  $localStorage[$scope.league].Uniques.forEach(function (item, index, array) {
    count++;
    if ($scope.unique == item) {
      $scope.commonRank = count;
    }
  });

  var ord=["th","st","nd","rd"],
  ordv=$scope.commonRank%100;
  $scope.commonRankOrd = (ord[(ordv-20)%10]||ord[ordv]||ord[0]);
  $scope.totalCount = count;

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
    if (response.aggregations.corrupted.buckets[0].key == 1) {
      $scope.corruptedTotal = response.aggregations.corrupted.buckets[0].doc_count
      $scope.corruptedPercent = (response.aggregations.corrupted.buckets[0].doc_count / response.hits.total) * 100;
    } else if (response.aggregations.corrupted.buckets[1].key == 1) {
      $scope.corruptedTotal = response.aggregations.corrupted.buckets[1].doc_count
      $scope.corruptedPercent = (response.aggregations.corrupted.buckets[1].doc_count / response.hits.total) * 100;
    }

    // Iterate through verified to separate out YES, NO, GONE, OLD
    $scope.verified = new Object();
    response.aggregations.verified.buckets.forEach(function (item, index, array) {
      $scope.verified[item.key] = item.doc_count;

    });


    var HistoData = new Array();
    // Loop through histo data to populate graph objects
    response.aggregations.histoAdded.buckets.forEach(function (time, index, array) {
      var MyRow = new Array();
      MyRow[0] = time.key;
      MyRow[1] = time.doc_count;
      HistoData.push(MyRow);
    }); 

$scope.HistoData = HistoData;

    // Force use of the comma separator for numbers, highcharts seems to default to spaces, bleh
    Highcharts.setOptions({
      lang: {
        thousandsSep: ','
      }
    });

    // Draw Graphs
    $('#GraphAdded').highcharts('StockChart', {
      rangeSelector : {
        allButtonsEnabled: true,
        buttons: [{
          type: 'day',
          count: 1,
          text: '1d'
        },{
          type: 'week',
          count: 1,
          text: '1w'
        },{
          type: 'month',
          count: 1,
          text: '1m'
        }],
        selected : 1
      },
      title : {
        text : 'Added to Shops Per Day'
      },
      colors: ['#cc0000'],
      series : [{
        name : 'Added',
        data : HistoData,
        type : 'area',
        fillColor : {
          linearGradient : {
            x1: 0,
            y1: 0,
            x2: 0,
            y2: 1
          },
          stops : [
            [0, '#cc0000'],
            [1, Highcharts.Color('#cc0000').setOpacity(0).get('rgba')]
          ]
        }
      }]
    });

    $scope.readyReport = true;
    // Clear loader
    $("#loader").html('');
  }, function (err) {
    console.trace(err.message);
  });

  return true;
});

