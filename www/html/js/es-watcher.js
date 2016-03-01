// We define an EsConnector module that depends on the elasticsearch module.     
var EsConnector = angular.module('EsConnector', ['elasticsearch','ui.bootstrap','ui.grid','ui.grid.autoResize','ngRoute']).config( ['$routeProvider', function($routeProvider) {
$routeProvider
  .when('/:sellerAccount', {
    templateUrl: 'shop-report.html',
    controller: 'shopReport',
    sellerAccount: 'sellerAccount'
  })
  .otherwise({
    redirectTo: '/'
  });
}]);



// Create the es service from the esFactory
// NOTE: Please do not use this API key if you re-host this page or fork this. Sign up for your own.
// This key may be expired at any time and I need a way to notify people of changes in the API
EsConnector.service('es', function (esFactory) {
//  return esFactory({ host: 'http://apikey:3fcfca58ada145a27b5de1f824111cd5@api.exiletools.com' });
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


EsConnector.controller('selectAccount', function($scope, $routeParams, es, $location) {

  // If a league is clicked, load the report for that league
  $scope.selectSellerAccount = function () {
    $location.path($scope.sellerAccount);
    console.log($scope.sellerAccount + " sellerAccount selected");
    return;
  }

});

EsConnector.controller('shopReport', function($scope, $routeParams, es, $location, $interval) {
  // Pull the league from the URL
  $scope.sellerAccount = $routeParams.sellerAccount;

  $scope.Timer = null;
  var runCount = 0;


  $scope.CheckTime = new Date().getTime();

  //Timer start function.
  $scope.StartTimer = function () {
    //Set the Timer start message.
    $scope.Message = "Monitoring started. ";

    //Initialize the Timer to run every 1000 milliseconds i.e. one second.
    $scope.Timer = $interval(function () {
      runCount++;
      var time = new Date();
      $scope.Message = "Scanning (" + runCount + ")... " + time;
      if (runCount > 99) {
        $scope.StopTimer();
      }

      es.search({
        index: 'index',
        body: {
          "sort": [
            { "shop.modified" : { "order" : "desc" } }
          ],
          "query": {
            "bool": {
              "must": [
                {
                  "range": {
                    "shop.modified": {
                      "gte": $scope.CheckTime,
                    }
                  }
                },
                {
                  "term": {
                    "shop.sellerAccount": {
                      "value": $scope.sellerAccount
                    }
                  }
                }
              ]
            }
          },
          size:100
        }
      }).then(function (response) {
        $scope.TabData = new Array();
        if (response.hits.total > 0) {
          // Loop through all the ItemsInLeagues buckets
          response.hits.hits.forEach(function (item, index, array) {
            tmp = new Object();
            tmp.itemName = item._source.info.fullName;
            tmp.modifiedAt = item._source.shop.modified;
            tmp.note = item._source.shop.note;
            tmp.currency = item._source.shop.currency;
            tmp.amount = item._source.shop.amount;
            tmp.stashName = item._source.shop.stash.stashName;
            tmp.xLocation = item._source.shop.stash.xLocation;
            tmp.yLocation = item._source.shop.stash.yLocation;
            tmp.VerifiedStatus = item._source.shop.verified;
            $scope.TabData.push(tmp);
          });
//          $scope.TabData.reverse();
          $scope.TabDataIsPopulated = 1;
        }
      }, function (err) {
        // Push an error into the loader div
        console.trace(err.message);
      });




      $scope.LastCheckTime = $scope.CheckTime;
    }, 20000);
  };

  //Timer stop function.
  $scope.StopTimer = function () {
    //Set the Timer stop message.
    $scope.Message = "Monitoring stopped.";

    //Cancel the Timer.
    if (angular.isDefined($scope.Timer)) {
      $interval.cancel($scope.Timer);
    }
  };


  return true;
});

