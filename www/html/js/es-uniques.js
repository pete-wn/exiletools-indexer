// We define an EsConnector module that depends on the elasticsearch module.     
var EsConnector = angular.module('EsConnector', ['elasticsearch','ui.bootstrap','ui.grid','ui.grid.autoResize','angularPromiseButtons','angular-cache','ngRoute','ui.select','ngStorage','highcharts-ng']).config( ['$routeProvider', function($routeProvider) {
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
      console.log("League Chooser Search executed in " + (searchEnd - searchStart) + "ms");
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
    $("#loader").html('<div style="min-width:200px;max-width:500px" class="alert alert-warning" role="alert"><i class="fa fa-gear fa-spin" style="font-size:500%"></i> Populating unique item list for ' + $scope.league + '...</div>');
  
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
  $("#loader").html('<div style="min-width:200px;max-width:500px" class="alert alert-warning" role="alert"><i class="fa fa-gear fa-spin" style="font-size:500%"></i> Creating report for ' + $scope.unique + " in " + $scope.league + '...</div>');

  // Set the currency icon object
  $scope.CurrencyIcons = new Object();
  $scope.CurrencyIcons["Blessed Orb"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyImplicitMod.png";
  $scope.CurrencyIcons["Cartographers Chisel"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyMapQuality.png";
  $scope.CurrencyIcons["Chaos Orb"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyRerollRare.png";
  $scope.CurrencyIcons["Chromatic Orb"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyRerollSocketColours.png";
  $scope.CurrencyIcons["Divine Orb"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyModValues.png";
  $scope.CurrencyIcons["Eternal Orb"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyImprintOrb.png";
  $scope.CurrencyIcons["Exalted Orb"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyAddModToRare.png";
  $scope.CurrencyIcons["Gemcutters Prism"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyGemQuality.png";
  $scope.CurrencyIcons["Jewellers Orb"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyRerollSocketNumbers.png";
  $scope.CurrencyIcons["Mirror of Kalandra"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyDuplicate.png";
  $scope.CurrencyIcons["Orb of Alchemy"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyUpgradeToRare.png";
  $scope.CurrencyIcons["Orb of Alteration"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyRerollMagic.png";
  $scope.CurrencyIcons["Orb of Chance"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyUpgradeRandomly.png";
  $scope.CurrencyIcons["Orb of Fusing"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyRerollSocketLinks.png";
  $scope.CurrencyIcons["Orb of Regret"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyPassiveSkillRefund.png";
  $scope.CurrencyIcons["Orb of Scouring"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyConvertToNormal.png";
  $scope.CurrencyIcons["Portal Scroll"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyPortal.png";
  $scope.CurrencyIcons["Regal Orb"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyUpgradeMagicToRare.png";
  $scope.CurrencyIcons["Scroll of Wisdom"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyIdentification.png";
  $scope.CurrencyIcons["Vaal Orb"] = "http://webcdn.pathofexile.com/image/Art/2DItems/Currency/CurrencyVaal.png";

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
  var search3Promise = 'pending';
  var search4Promise = 'pending';

  // Various Graph Data Arrays
  var Chart1x1 = new Array();
  var Chart1x2 = new Array();
  var Chart2x1 = new Array();
  var Chart2x2 = new Array();
  var Chart2x3 = new Array();

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
    $("#loader").append('<div style="min-width:200px;max-width:500px" class="alert alert-success" role="alert">Gathered general statistics in ' + (searchEnd - searchStart) + 'ms</div>');

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
      $scope.corruptedPercent = ((response.aggregations.corrupted.buckets[0].doc_count / response.hits.total) * 100).toFixed(1);
    } else if (response.aggregations.corrupted.buckets[1] && response.aggregations.corrupted.buckets[1].key == 1) {
      $scope.corruptedTotal = response.aggregations.corrupted.buckets[1].doc_count
      $scope.corruptedPercent = ((response.aggregations.corrupted.buckets[1].doc_count / response.hits.total) * 100).toFixed(1);
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
    $scope.unidentifiedPercent = (($scope.unidentifiedTotal / response.hits.total) * 100).toFixed(1);
    $scope.itemsTotal = $scope.identifiedTotal + $scope.unidentifiedTotal;

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
      tmp.icon = $scope.CurrencyIcons[item.key];
      tmp.itemsListedForCurrency = item.doc_count;
      $scope.currencyTypes.push(tmp);
    });

    // Loop through histo data to populate graph objects
    response.aggregations.histoAdded.buckets.forEach(function (time, index, array) {
      var MyLine = [time.key,time.doc_count];
      Chart1x1.push(MyLine);
    }); 


  
    search1Promise = 'resolved'; 
    resolve(search1Promise, search2Promise, search3Promise, search4Promise);
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
    $("#loader").append('<div style="min-width:200px;max-width:500px" class="alert alert-success" role="alert">Gathered pricing statistics in ' + (searchEnd - searchStart) + 'ms</div>');

    // Set various scope variables
    $scope.uniqueSellersWithPrice = response.aggregations.uniqueSellers.value;

    // Iterate through verified to separate out YES, NO, GONE, OLD
    $scope.verifiedPrice = new Object();
    response.aggregations.verified.buckets.forEach(function (item, index, array) {
      $scope.verifiedPrice[item.key] = item.doc_count;
    });

    // Percentile Price Data
    $scope.value = new Object();
    $scope.value.allTime5 = response.aggregations.percentilePrices.values["5.0"];
    $scope.value.allTime5Type = "Chaos";
    $scope.value.allTime15 = response.aggregations.percentilePrices.values["15.0"];
    $scope.value.allTime15Type = "Chaos";
    $scope.value.allTime50 = response.aggregations.percentilePrices.values["50.0"];
    $scope.value.allTime50Type = "Chaos";

   // Modify chaos to ex for display
   if ($scope.value.allTime5 >= 80) { $scope.value.allTime5 = $scope.value.allTime5 / 80; $scope.value.allTime5Type = "Exalt"; };
   if ($scope.value.allTime15 >= 80) { $scope.value.allTime15 = $scope.value.allTime15 / 80; $scope.value.allTime15Type = "Exalt"; };
   if ($scope.value.allTime50 >= 80) { $scope.value.allTime50 = $scope.value.allTime50 / 80; $scope.value.allTime50Type = "Exalt"; };

    search2Promise = 'resolved';
    resolve(search1Promise, search2Promise, search3Promise, search4Promise);
  }, function (err) {
    console.trace(err.message);
  });

  // Query 3: Pricing Data for GONE items
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
                { "term" : { "shop.verified" : "GONE" } },
                { "range" : { "shop.chaosEquiv" : { "gt" : 0 } } }
              ]
            }
          }
        }
      },
      "aggs": {
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
        "histoModified": {
          "date_histogram": {
            "field": "shop.modified",
            "interval": "day"
          },
          "aggs": {
            "percentilePrice": {
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
            }
          }
        },
        "currencyType": {
          "terms": {
            "field": "shop.currency",
            "size": 20
          },
          "aggs": {
            "currencyAmount": {
              "terms": {
                "field": "shop.amount",
                "size": 10
              }
            }
          }
        }
      },
      size:0
    }
  }).then(function (response) {
    var searchEnd = new Date();
    console.log("Generating Report: Query 3 executed in " + (searchEnd - searchStart) + "ms");
    // Append loading data
    $("#loader").append('<div style="min-width:200px;max-width:500px" class="alert alert-success" role="alert">Gathered general statistics on GONE items in ' + (searchEnd - searchStart) + 'ms</div>');

    // Percentile price data 
    $scope.valueGONE = new Object();
    $scope.valueGONE.allTime5 = response.aggregations.percentilePrices.values["5.0"];
    $scope.valueGONE.allTime5Type = "Chaos";
    $scope.valueGONE.allTime15 = response.aggregations.percentilePrices.values["15.0"];
    $scope.valueGONE.allTime15Type = "Chaos";
    $scope.valueGONE.allTime50 = response.aggregations.percentilePrices.values["50.0"];
    $scope.valueGONE.allTime50Type = "Chaos";
   
    // Modify chaos to ex for display
    if ($scope.valueGONE.allTime5 >= 80) { $scope.valueGONE.allTime5 = $scope.valueGONE.allTime5 / 80; $scope.valueGONE.allTime5Type = "Exalt"; };
    if ($scope.valueGONE.allTime15 >= 80) { $scope.valueGONE.allTime15 = $scope.valueGONE.allTime15 / 80; $scope.valueGONE.allTime15Type = "Exalt"; };
    if ($scope.valueGONE.allTime50 >= 80) { $scope.valueGONE.allTime50 = $scope.valueGONE.allTime50 / 80; $scope.valueGONE.allTime50Type = "Exalt"; };

    // Loop through histo data to populate graph objects
    response.aggregations.histoModified.buckets.forEach(function (time, index, array) {
      var MyLine = [time.key,time.percentilePrice.values["5.0"]];
      Chart2x1.push(MyLine);
      var MyLine = [time.key,time.percentilePrice.values["15.0"]];
      Chart2x2.push(MyLine);
      var MyLine = [time.key,time.percentilePrice.values["50.0"]];
      Chart2x3.push(MyLine);
    });

    var commonGonePrices = new Object();
    // Calculate the 10 most common original currency requests by iterating through each type/amount
    response.aggregations.currencyType.buckets.forEach(function (type, index, array) {
      type.currencyAmount.buckets.forEach(function (amount, index, array) {
        if (commonGonePrices[amount.doc_count] == null) { commonGonePrices[amount.doc_count] = new Array() };
        commonGonePrices[amount.doc_count].push(amount.key + " " + type.key);
      });
    });
    // Create an empty count variable for iterating the object since we care about total items in all arrays
    var priceCount = 0;
    // Create an empty object to push the prices onto for output
    $scope.commonGonePrice = new Array();
    // in case two different prices have the same count
    Object.keys(commonGonePrices).sort(function(a, b){return a-b}).reverse().forEach(function(key) {
      commonGonePrices[key].forEach(function(line) {
        priceCount++;
        if (priceCount > 10) { return };
        var type = line.replace(/^\S+ /,"");;
        tmp = new Object();
        tmp.CommonPrices = line;
        tmp.icon = $scope.CurrencyIcons[type];
        tmp.numberGoneAtPrice = key;
        $scope.commonGonePrice.push(tmp);
      });
    });



    search3Promise = 'resolved';
    resolve(search1Promise, search2Promise, search3Promise, search4Promise);
  }, function (err) {
    console.trace(err.message);
  });

  // Query 4: Histogram data for GONE items
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
                { "term" : { "shop.verified" : "GONE" } }
              ]
            }
          }
        }
      },
      "aggs": {
        "histoModified": {
          "date_histogram": {
            "field": "shop.modified",
            "interval": "day"
          }
        }
      },
      size:0
    }
  }).then(function (response) {
    var searchEnd = new Date();
    console.log("Generating Report: Query 4 executed in " + (searchEnd - searchStart) + "ms");
    // Append loading data
    $("#loader").append('<div style="min-width:200px;max-width:500px" class="alert alert-success" role="alert">Gathered histogram data on GONE items in ' + (searchEnd - searchStart) + 'ms</div>');


    // Loop through histo data to populate graph objects
    response.aggregations.histoModified.buckets.forEach(function (time, index, array) {
      var MyLine = [time.key,time.doc_count];
      Chart1x2.push(MyLine);
    });

    search4Promise = 'resolved';
    resolve(search1Promise, search2Promise, search3Promise, search4Promise);
  }, function (err) {
    console.trace(err.message);
  });

  // This is my own function that is called after each search and only triggers
  // if all searches are set to resolved
  function resolve(search1Promise, search2Promise, search3Promise, search4Promise) {
    if (search1Promise == 'resolved' && search2Promise == 'resolved' && search3Promise == 'resolved' && search4Promise == 'resolved') {
      // Clear loader
      $("#loader").empty();

      // UI-Grid Tables
      $scope.CurrencyTypesGridOptions = {
        data : $scope.currencyTypes,
        enableHorizontalScrollbar : 0,
        columnDefs: [
          { name: '', field: 'icon', cellTemplate:"<img height=\"27\" ng-src=\"{{grid.getCellValue(row, col)}}\" lazy-src>", enableColumnResizing: false, width: 40, enableSorting: false, enableColumnMenu: false},
          { name: 'Currency Type Requested', field: 'currencyTypeRequested' },
          { name: '# Listed for Currency Type', field: 'itemsListedForCurrency', type: 'number' },
          ]
      };
      
      $scope.commonPricesGoneGridOptions = {
        data : $scope.commonGonePrice,
        enableHorizontalScrollbar : 0,
        columnDefs: [
          { name: '', field: 'icon', cellTemplate:"<img height=\"27\" ng-src=\"{{grid.getCellValue(row, col)}}\" lazy-src>", enableColumnResizing: false, width: 40, enableSorting: false, enableColumnMenu: false},
          { name: 'Most Common Prices', field: 'CommonPrices' },
          { name: '# Gone At This Price', field: 'numberGoneAtPrice', type: 'number' },
          ]
      };


      // A simple gauge for Unidentified 
      $scope.gauge1UnidConfig = {
        options : {
          chart: {
            type: 'solidgauge',
            backgroundColor: 'transparent'
          },
          pane: {
            center: ['50%', '50%'],
            size: '100%',
            startAngle: -120,
            endAngle: 120,
            background: {
              backgroundColor: '#EEE',
              innerRadius: '70%',
              outerRadius: '100%',
              shape: 'arc'
            }
          },
          credits: {
            enabled: false
          },
          tooltip: {
            enabled: false
          },
          plotOptions: {
            solidgauge: {
              innerRadius: '70%',
              dataLabels: {
                y: -80,
                borderWidth: 0,
                useHTML: true,
                zIndex: 1
              }
            }
          },
          title: null,
        },
        yAxis: {
          currentMin: 0,
          currentMax: $scope.itemsTotal,
          title: null,
          stops: [
            [0.05, '#55BF3B'], // green
            [0.1, '#DDDF0D'], // yellow
            [0.2, '#DF5353'] // red
          ]
        },
        series: [{
          name: 'Unidentified',
          data: [$scope.unidentifiedTotal],
          dataLabels : {
            format: '<div style="text-align:center"><span style="font-size:45px;color:#808080">' + $scope.unidentifiedPercent + '%</span><br/><span style="font-size:12px;color:#808080">{y}<br/></span><span style="font-size:30px;color:#808080">Unidentified</span></div>'
          },
        }],
        useHighStocks: false
      }

      // A simple guage for Corrupted
      $scope.gauge2CorruptedConfig = {
        options : {
          chart: {
            type: 'solidgauge'
          },
          pane: {
            center: ['50%', '50%'],
            size: '100%',
            startAngle: -120,
            endAngle: 120,
            background: {
              backgroundColor: '#EEE',
              innerRadius: '70%',
              outerRadius: '100%',
              shape: 'arc'
            }
          },
          credits: {
            enabled: false
          },
          tooltip: {
            enabled: false
          },
          plotOptions: {
            solidgauge: {
              innerRadius: '70%',
              dataLabels: {
                y: -80,
                borderWidth: 0,
                useHTML: true
              }
            }
          },
          title: null,
        },
        yAxis: {
          currentMin: 0,
          currentMax: $scope.itemsTotal,
          title: null,
          stops: [
            [0.1, '#55BF3B'], // green
            [0.5, '#DDDF0D'], // yellow
            [0.9, '#DF5353'] // red
          ]
        },
        series: [{
          name: 'Corrupted',
          data: [$scope.corruptedTotal],
          dataLabels : {
            format: '<div style="text-align:center"><span style="font-size:45px;color:darkred">' + $scope.corruptedPercent + '%</span><br/><span style="font-size:12px;color:darkred">{y}<br/></span><span style="font-size:30px;color:darkred">Corrupted</span></div>'
          },
        }],
        useHighStocks: false
      }

      // A simple guage for Gone Percentage
      $scope.goneRatioPercent = ($scope.verified.GONE / ($scope.verified.GONE + $scope.verified.YES) * 100).toFixed(1);
      $scope.gauge3GoneRatioConfig = {
        options : {
          chart: {
            type: 'solidgauge'
          },
          pane: {
            center: ['50%', '50%'],
            size: '100%',
            startAngle: -120,
            endAngle: 120,
            background: {
              backgroundColor: '#EEE',
              innerRadius: '70%',
              outerRadius: '100%',
              shape: 'arc'
            }
          },
          credits: {
            enabled: false
          },
          tooltip: {
            enabled: false
          },
          plotOptions: {
            solidgauge: {
              innerRadius: '70%',
              dataLabels: {
                y: -80,
                borderWidth: 0,
                useHTML: true
              }
            }
          },
          title: null,
        },
        yAxis: {
          currentMin: 0,
          currentMax: $scope.itemsTotal,
          title: null,
          stops: [
            [0.45, '#DF5353'], // red
            [0.6, '#DDDF0D'], // yellow
            [0.8, '#55BF3B'] // green
          ]
        },
        series: [{
          name: 'GoneAmount',
          data: [$scope.verified.GONE],
          dataLabels : {
            format: '<div style="text-align:center"><span style="font-size:45px;color:darkorange">' + $scope.goneRatioPercent + '%</span><br/><span style="font-size:12px;color:darkorange">' + $scope.verified.GONE + '<br/></span><span style="font-size:30px;color:darkorange">Gone</span></div>'
          },
        }],
        useHighStocks: false
      }

      //Use Chart1 data to show Added / Removed Counts in Highstock
      $scope.chart1AddedRemovedConfig = {
        options: {
          chart: {
            zoomType: 'x'
          },
          rangeSelector: {
            enabled: true
          },
          navigator: {
            enabled: true
          }
        },
        series: [{
          id: 'Added',
          name: 'Added',
          type: 'column',
          data:  Chart1x1
        }, {
          id: 'Modified',
          name: 'Removed',
          type: 'line',
          data:  Chart1x2
        }],
        title: {
          text: "Total Added and Removed (GONE) per Day"
        },
        useHighStocks: true
      }

      //Use Chart2 data to show Prices in Highstock
      $scope.chart2PricesConfig = {
        options: {
          chart: {
            zoomType: 'x'
          },
          rangeSelector: {
            enabled: true
          },
          navigator: {
            enabled: true
          }
        },
        series: [{
          id: 'GONE5',
          name: 'GONE 5th %',
          type: 'line',
          data:  Chart2x1
        }, {
          id: 'GONE15',
          name: 'GONE 15th %',
          type: 'line',
          data:  Chart2x2
        }, {
          id: 'GONE50',
          name: 'GONE 50th %',
          type: 'line',
          data:  Chart2x3
        }],
        title: {
          text: "Historical GONE Percentile Prices in Chaos Equivalent"
        },
        useHighStocks: true
      }

      // Stats on report generation
      var searchEnd = new Date();
      console.log("Generating Report: All processing finished in " + (searchEnd - searchStart) + "ms");

      // Briefly show report generation statistics in the loader div
      $("#loader").append('<div style="min-width:200px;max-width:500px" class="alert alert-success" role="alert">Created full report in ' + (searchEnd - searchStart) + 'ms</div>');
      setTimeout(function(){ $("#loader").empty(); }, 2000);


      // Set readyReport to true to show data in Angular
      $scope.readyReport = true;
     
    }
  }

  return true;
});

