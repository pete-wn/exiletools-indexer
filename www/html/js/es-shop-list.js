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

EsConnector.controller('shopReport', function($scope, $routeParams, es, $location) {
  // Pull the league from the URL
  $scope.sellerAccount = $routeParams.sellerAccount;

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
              "term": {
                "shop.sellerAccount": {
                  "value": $scope.sellerAccount
                }
              }
            }
          ]
        }
      },
      size:10000
    }
  }).then(function (response) {
    $scope.TabData = new Array();
    if (response.hits.total > 0) {
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
      $scope.TabDataIsPopulated = 1;
    }
  }, function (err) {
    // Push an error into the loader div
    console.trace(err.message);
  });

  return true;
});

