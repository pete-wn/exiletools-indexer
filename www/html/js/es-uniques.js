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
      console.log("Unique Item List Search executed in " + (searchEnd - searchStart) + "ms");
  
  
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

  // Start a timer for searches
  var searchStart = new Date();
  // Prepare some promise variables 
  // yeah I have no idea how to use promises so I wrote my o wn
  var search1Promise = 'pending';
  var search2Promise = 'pending';

  // Query 1: General Statistics
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
    "identified": {
      "terms": {
        "field": "attributes.identified"
      }
    },
    "histoAdded": {
      "date_histogram": {
        "field": "shop.added",
        "interval": "day"
      }
    },
    "currencyType": {
      "terms": {
        "field": "shop.currency"
      }
    },
    "uniqueSellers" : {
      "cardinality": {
        "field": "shop.sellerAccount"
      }
    }
  },
  size:0
    }
  }).then(function (response) {
    var searchEnd = new Date();
    console.log("Generating Report: Query 1 executed in " + (searchEnd - searchStart) + "ms");
    // Append loading data
    $("#loader").append('<div style="width:600px" class="alert alert-success" role="alert">Gathered general statistics in ' + (searchEnd - searchStart) + 'ms</div>');

    // stuff
    var Icons = new Array();
    response.aggregations.icons.buckets.forEach(function (item, index, array) {
      Icons.push(item.key);
    });
    $scope.Icons = Icons;

    // Set some other variables from the data
    $scope.baseItemType = response.aggregations.baseItemType.buckets[0].key;
    $scope.itemType = response.aggregations.itemType.buckets[0].key;
    $scope.equipType = response.aggregations.equipType.buckets[0].key;
    $scope.uniqueSellers = response.aggregations.uniqueSellers.value;

    // Count of corrupted items
    if (response.aggregations.corrupted.buckets[0].key == 1) {
      $scope.corruptedTotal = response.aggregations.corrupted.buckets[0].doc_count
      $scope.corruptedPercent = (response.aggregations.corrupted.buckets[0].doc_count / response.hits.total) * 100;
    } else if (response.aggregations.corrupted.buckets[1] && response.aggregations.corrupted.buckets[1].key == 1) {
      $scope.corruptedTotal = response.aggregations.corrupted.buckets[1].doc_count
      $scope.corruptedPercent = (response.aggregations.corrupted.buckets[1].doc_count / response.hits.total) * 100;
    }

    // Identified vs unidentified
    if (response.aggregations.identified.buckets[0].key == 1) {
      $scope.identifiedTotal = response.aggregations.identified.buckets[0].doc_count
      $scope.identifiedPercent = (response.aggregations.identified.buckets[0].doc_count / response.hits.total) * 100;
    } else if (response.aggregations.identified.buckets[1] && response.aggregations.identified.buckets[1].key == 1) {
      $scope.identifiedTotal = response.aggregations.identified.buckets[1].doc_count
      $scope.identifiedPercent = (response.aggregations.identified.buckets[1].doc_count / response.hits.total) * 100;
    } 
    $scope.unidentifiedTotal = response.hits.total - $scope.identifiedTotal;
    $scope.unidentifiedPercent = ($scope.unidentifiedTotal / response.hits.total) * 100;

    // Iterate through verified to separate out YES, NO, GONE, OLD
    $scope.verified = new Object();
    response.aggregations.verified.buckets.forEach(function (item, index, array) {
      $scope.verified[item.key] = item.doc_count;
    });

    // Iterate through currency to build an object of currency types
    $scope.currencyTypes = new Array();
    response.aggregations.currencyType.buckets.forEach(function (item, index, array) {
      tmp = new Object();
      tmp.currencyTypeRequested = item.key;
      tmp.itemsListedForCurrency = item.doc_count;
      $scope.currencyTypes.push(tmp);
    });
  
// We should do this via angular modules for highcharts instead
//    var HistoData = new Array();
    // Loop through histo data to populate graph objects
//    response.aggregations.histoAdded.buckets.forEach(function (time, index, array) {
//      var MyRow = new Array();
//      MyRow[0] = time.key;
//      MyRow[1] = time.doc_count;
//      HistoData.push(MyRow);
//    }); 
//
//    $scope.HistoData = HistoData;

  
    search1Promise = 'resolved'; 
    resolve(search1Promise, search2Promise);
  }, function (err) {
    console.trace(err.message);
  });

  // Query 2: Statistics for items with prices
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
            { "term" : { "info.fullName" : $scope.unique } },
            { "range" : { "shop.chaosEquiv" : { "gt" : 0 } } }
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
    "uniqueSellers" : {
      "cardinality": {
        "field": "shop.sellerAccount"
      }
    },
    "percentilePrices" : {
      "percentiles": {
        "field": "shop.chaosEquiv",
        "percents": [
          1,
          5,
          15,
          30,
          50,
          75,
          95
        ]
      }
    },
    "statsPrices" : {
      "extended_stats": {
        "field": "shop.chaosEquiv"
      }
    },
    "currencyType": {
      "terms": {
        "field": "shop.currency"
      }
    }
  },
  size:0
    }
  }).then(function (response) {
    var searchEnd = new Date();
    console.log("Generating Report: Query 2 executed in " + (searchEnd - searchStart) + "ms");
    // Append loading data
    $("#loader").append('<div style="width:600px" class="alert alert-success" role="alert">Gathered pricing statistics in ' + (searchEnd - searchStart) + 'ms</div>');

    // Iterate through verified to separate out YES, NO, GONE, OLD
    $scope.verifiedPrice = new Object();
    response.aggregations.verified.buckets.forEach(function (item, index, array) {
      $scope.verifiedPrice[item.key] = item.doc_count;
    });

   $scope.value = new Object();
   $scope.value.allTime5 = response.aggregations.percentilePrices.values["5.0"];
   $scope.value.allTime5Type = "Chaos";
   $scope.value.allTime15 = response.aggregations.percentilePrices.values["15.0"];
   $scope.value.allTime15Type = "Chaos";
   $scope.value.allTime50 = response.aggregations.percentilePrices.values["50.0"];
   $scope.value.allTime50Type = "Chaos";

   // Modify chaos to ex for display
   if ($scope.value.allTime5 > 80) { $scope.value.allTime5 = $scope.value.allTime5 / 80; $scope.value.allTime5Type = "Exalts"; };
   if ($scope.value.allTime15 > 80) { $scope.value.allTime15 = $scope.value.allTime15 / 80; $scope.value.allTime15Type = "Exalts"; };
   if ($scope.value.allTime50 > 80) { $scope.value.allTime50 = $scope.value.allTime50 / 80; $scope.value.allTime50Type = "Exalts"; };








    search2Promise = 'resolved';
    resolve(search1Promise, search2Promise);
  }, function (err) {
    console.trace(err.message);
  });




  // This is my own function that is called after each search and only triggers
  // if all searches are set to resolved
  function resolve(search1Promise, search2Promise) {
    if (search1Promise == 'resolved' && search2Promise == 'resolved') {
      // Clear loader
      $("#loader").empty();

      var searchEnd = new Date();
      console.log("Generating Report: All processing finished in " + (searchEnd - searchStart) + "ms");
      // Briefly show report generation statistics in the loader div
      $("#loader").append('<div style="width:600px" class="alert alert-success" role="alert">Created full report in ' + (searchEnd - searchStart) + 'ms</div>');
      setTimeout(function(){ $("#loader").empty(); }, 2000);


      // Set readyReport to true to show data in Angular
      $scope.readyReport = true;
    }
  }

  return true;
});

