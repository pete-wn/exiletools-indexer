var elasticsearch = require('elasticsearch');
var client = new elasticsearch.Client({
  host: 'localhost:9200',
// host: 'http://exiletools.com/index'
  log: 'trace'
});

client.search({
  index: 'poe',
  type: 'item',
  body: {
"query": {
  "bool": {
    "must": [
      { "range": {
        "shop.updated": {
          "gte": "now-7d/d"
        }
      }},
      { "term": {
        "attributes.baseItemType": {
          "value": "Card"
        }
      }},
      { "term": {
        "shop.hasPrice": {
          "value": "true"
        }
      }},
      { "term": {
        "attributes.league": {
          "value": "Prophecy"
        }
      }}
    ]
  }
},
"aggs": {
  "name": {
    "terms": {
      "field": "info.fullName",
      "size": 200,
      "order": {
        "percentiles.25": "desc"
      }
    },
    "aggs": {
      "percentiles": {
        "percentiles": {
          "field": "shop.chaosEquiv",
          "percents": [
            25
          ]
        }
      }
    }
  }
}, 
size:0
  }
}).then(function (resp) {

  resp.aggregations.name.buckets.forEach(function(agg) {
    console.log('"' + agg.key + '",' + agg.percentiles.values["25.0"]);
  });

});
