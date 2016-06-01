// We define an EsConnector module that depends on the elasticsearch module.     
var EsConnector = angular.module('EsConnector', ['elasticsearch','ui.bootstrap','ui.grid','ui.grid.autoResize','angularPromiseButtons','angular-cache','ngRoute','ui.select','ngStorage','highcharts-ng']).config( ['$routeProvider', function($routeProvider) {
$routeProvider
  .when('/:league/:unique/:options/:links', {
    templateUrl: 'uniqueReport.html',
    controller: 'uniqueReport',
  })
  .when('/:league/:unique/:options', {
    templateUrl: 'uniqueReport.html',
    controller: 'uniqueReport',
  })
  .when('/:league/:unique', {
    redirectTo: '/:league/:unique/PastWeek'
  })
  .when('/:league', {
    templateUrl: 'search.html',
    controller: 'realtimeSearch',
    league: 'league'
  })
  .otherwise({
    redirectTo: '/'
  });
}]);



// Create the es service from the esFactory
// NOTE: Please do not use this API key if you re-host this page or fork this. Sign up for your own.
// This key may be expired at any time and I need a way to notify people of changes in the API
EsConnector.service('es', function (esFactory) {
  return esFactory({ host: 'http://apikey:3fcfca58ada145a27b5de1f824111cd5@api.exiletools.com' });
});

// We define an Angular controller that returns the server health
// Inputs: $scope and the 'es' service

EsConnector.controller('ServerHealthController', function($scope, es) {
    es.cluster.health(function (err, resp) {
        if (err) {
          // Push an error into the loader div
          $("#loader").html('<div style="min-width:200px;max-width:1000px" class="alert alert-danger" role="alert"><i class="fa fa-warning" style="font-size:500%"></i> Something went wrong checking the ES Index health / connection!<br/><br/>Please try reloading this page. If the error continues, please access the developer console to see the underlying error and contact pete@pwx.me for help.</div>');
            $scope.data = err.message;
        } else {
            $scope.data = resp;
        }
    });
});


// init function for the Chooser so it can be loaded in multiple controllers
var initChooser = function($scope, es, $location, $localStorage, $sessionStorage) {
  // Check to see if we have the LeagueStats in localStorage already and if it's not too old (10min)
  if ($localStorage.LeagueStats && (new Date() - $localStorage.AgeLeagueStats) < 600000) {
    console.log("initChooser: LeagueStats are in local storage as of " + $localStorage.AgeLeagueStats + ", using cached data");
    $scope.LeagueStats = $localStorage.LeagueStats;
  } else {
    console.log("initChooser: LeagueStats aren't in local storage or are out of date, performing new search.");
    // Start loading icon
    $("#loader").html('<div style="min-width:200px;max-width:500px" class="alert alert-warning" role="alert"><i class="fa fa-gear fa-spin" style="font-size:500%"></i>Loading league list...</div>');

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
      // Create an information Array
      LeagueStats = new Object();
   
      // Keep track of the number of leagues returned
      var LeaguesFound = 0; 

      // Loop through all the ItemsInLeagues buckets
      response.aggregations.leagues.uniquesInLeagues.buckets.forEach(function (item, index, array) {
        // Add the total count information and league name
        LeagueStats[item.key] = item.doc_count;
        LeaguesFound++;
      });

      var searchEnd = new Date();
      console.log("initChooser: League Chooser Search executed in " + (searchEnd - searchStart) + "ms, found " + LeaguesFound + " leagues with uniques");

      // Throw an error if no leagues are in the list
      if (LeaguesFound < 1) {
      // Push an error into the loader div
        $("#loader").html('<div style="min-width:200px;max-width:1000px" class="alert alert-danger" role="alert"><i class="fa fa-warning" style="font-size:500%"></i> Something went wrong loading the league list!<br/><br/><br/>ERROR: No leagues found with unique items!<br/><br/>Something may be wrong with the ES index, please try again later or contact pete@pwx.me if the error continues.</div>');
        console.log('initChooser: ERROR: No leagues found with unique items! Something wrong with index?');
        return false;
      }

      // Return the array as LeagueStats to Angular
      $scope.LeagueStats = LeagueStats;
  
      // Set this in local storage
      $localStorage.LeagueStats = LeagueStats;
  
      // Set the time in local storage
      $localStorage.AgeLeagueStats = new Date().valueOf();

      // Clear loader
      $("#loader").html('');
      $("#loaderProgress").html('');
  
    }, function (err) {
      // Push an error into the loader div
      $("#loader").html('<div style="min-width:200px;max-width:1000px" class="alert alert-danger" role="alert"><i class="fa fa-warning" style="font-size:500%"></i> Something went wrong loading the league list!<br/><br/><br/>ERROR: ' + err.message + '<br/><br/>Please try reloading this page or contact pete@pwx.me if the error continues.</div>');
      console.trace(err.message);
    });
  }
  console.log('initChooser: leagueChooser initialized');
}

EsConnector.controller('leagueChooser', function($scope, $routeParams, es, $location, $localStorage, $sessionStorage ) {
  // Make sure the League Chooser is fully loaded
  initChooser($scope, es, $location, $localStorage, $sessionStorage);

  // If a league is clicked, load the report for that league
  $scope.selectLeague = function (league) {
    $location.path(league);
    console.log(league + " league selected");
    return;
  }

});


EsConnector.controller('realtimeSearch', function($scope, $routeParams, es, $localStorage, $sessionStorage, $http) {
  // Pull the League from the URL
  $scope.league = $routeParams.league;
  // Default readyReport to false
  $scope.readyReport = false;

  // Create a scope array for errors, if any
  $scope.errors = new Array;

  console.log($scope.league + " league selected");

  $scope.selectUniqueItemNames = new Array;
  $http.get('http://api.exiletools.com/endpoints/list-field-values?output=array&field=info.fullName&filters=attributes.rarity:Unique,attributes.league:' + $scope.league).then(
    function (response) {
      $scope.selectUniqueItemNames = response.data;
      $scope.selectUniqueItemNames.sort();
      console.log("Got field value data for selectUniqueItemNames");
    },
    function () {
      console.log('ERROR: Something went wrong trying to fetch the list of unique items!');
    }
  );

  $scope.selectBaseItemType = new Array;
  $http.get('http://api.exiletools.com/endpoints/list-field-values?field=attributes.baseItemType&output=array').then(
    function (response) {
      $scope.selectBaseItemType = response.data;
      $scope.selectBaseItemType.push("Any");
      $scope.selectBaseItemType.sort();
      console.log("Got field value data for selectBaseItemType");
    },
    function () {
      console.log('ERROR: Something went wrong trying to fetch the list of item item types!');
    }
  );

  $scope.selectRarity = new Array;
  $http.get('http://api.exiletools.com/endpoints/list-field-values?field=attributes.rarity&output=array').then(
    function (response) {
      $scope.selectRarity = response.data;
      $scope.selectRarity.push("Any");
      $scope.selectRarity.sort();
      console.log("Got field value data for selectRarity");
    },
    function () {
      console.log('ERROR: Something went wrong trying to fetch the list of item rarities!');
    }
  );

  // Set switches active
  $("[name='shop.hasPrice']").bootstrapSwitch();
  $("[name='attributes.identified']").bootstrapSwitch();
  $("[name='requirements.Level.minmax']").bootstrapSwitch();

  // Function to process item type selection
  $scope.chooseBaseItemType = function (baseItemType) {                                                                                                                     
    console.log(baseItemType + " selected");
    // Get a list of possible equip types
    $scope.selectEquipType = new Array;
    $http.get('http://api.exiletools.com/endpoints/list-field-values?field=attributes.equipType&filters=attributes.baseItemType:' + baseItemType + '&output=array').then(
      function (response) {
        $scope.selectEquipType = response.data;
      },
      function () {
        console.log('ERROR: Something went wrong trying to fetch the list of item equip types!');
      } 
    );
    $scope.chosenType = baseItemType;

    // If Gem was chosen, get a list of Gem Types from the mapping endpoint
    if ($scope.chosenType == 'Gem') {
      $http.get('http://exiletools.com/endpoints/mapping?field=properties.Gem.type').then(
        function (response) {
          $scope.gemTypes = new Array;
          var gemTypesAPI = response.data.split("\n");
          // Remove the trailing empty one after the split
          gemTypesAPI.pop();
          gemTypesAPI.forEach(function(type) {
            var shortType = type.replace("properties.Gem.type.","");
            $scope.gemTypes.push(shortType);
          });

          console.log("Got Gem Type Data");
        },
        function () {
          console.log('ERROR: Something went wrong trying to fetch Gem Type data!');
        }
      );
    }
  
    if ($scope.chosenType != 'Weapon') {
      $scope.selectItemType = new Array;
    }

    // We're using a function to list mods for appropriate items
    // At this point, we should call this function to show mods for any item
    // that won't require a subtype. For now, we're doing this manually.
    //
    // Items that have mods but no subtype include:
    //   Jewel
    //   Map
    //   Flask
    //   Gem
    //   Any

    if ($scope.chosenType == 'Jewel' || $scope.chosenType == 'Map' || $scope.chosenType == 'Flask' || $scope.chosenType == 'Gem' || $scope.chosenType == 'Any') {
      listMods($scope.chosenType);
    }

    return;
  } 

  // Function to process item type selection
  $scope.chooseEquipType = function (equipType) {
    console.log(equipType + " selected (chooseEquipType)");
    // Load additional information for Weapons
    if ($scope.chosenType == "Weapon") {
      $scope.selectItemType = new Array;
      $http.get('http://api.exiletools.com/endpoints/list-field-values?field=attributes.itemType&filters=attributes.equipType:' + equipType + '&output=array').then(
        function (response) {
          $scope.selectItemType = response.data;
        },
        function () {
          console.log('ERROR: Something went wrong trying to fetch the list of item item types!');
        }
      );
    } else {
      $scope.selectItemType = new Array;
    }
    return;
  }
  $scope.chooseItemType = function (itemType) {
    console.log(itemType + " chosen");
    return;
  }

  var listMods = function(type) {
    console.log("listing mods for " + type);
    $http.get('http://exiletools.com/endpoints/mapping?field=mods.' + type).then(
      function (response) {
        $scope.displayModData = new Array;
        var modsAPI = response.data.split("\n");
        // Remove the trailing empty one after the split
        modsAPI.pop();
        modsAPI.forEach(function(mod) {
          // Skip cosmetic mods
          if (/\.cosmetic\./.test(mod)) {
            return;
          }
          var shortMod = mod.replace(/^.*(explicit|implicit)\.(.*?)(\.min|\.max)*/, "$2");
          if ($scope.displayModData.indexOf(shortMod) == -1) {
            $scope.displayModData.push(shortMod);
          }
        });
        console.log("Got Mods data!");
        $scope.addModChoosers = [{id: 'mod1'}];
      },
      function () {
        console.log('ERROR: Something went wrong trying to fetch Mods data!');
      }
    );
  }

  $scope.addModChooser = function() {
    var newItemNo = $scope.addModChoosers.length+1;
    $scope.addModChoosers.push({'id':'mod'+newItemNo});
  };

  return true;
});

