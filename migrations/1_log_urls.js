'use strict';

var async = require('async'),
    config = require('../lib/config'),
    elasticSearchConnect = require('../lib/elasticsearch_connect'),
    logCleaner = require('../lib/log_processor/cleaner'),
    moment = require('moment'),
    mongoConnect = require('../lib/mongo_connect');

exports.migrate = function(client, done) {
  console.info('migrate!');
  async.parallel([
    mongoConnect,
    elasticSearchConnect,
  ], function(error, results) {
    var elasticSearch = results[1];

    var count = 0;
    var indexes = {};

    console.info('search!');
    elasticSearch.search({
      index: 'api-umbrella-logs-20*',
      search_type: 'scan',
      scroll: '5m',
      size: 1000,
      body: {
        query: {
          match_all: {},
        },
      },
    }, function getMoreUntilDone(error, response) {
      var bulkCommands = [];
      async.each(response.hits.hits, function(hit, callback) {
        count++;

        if(count % 100 === 0) {
          console.info('  Processing ' + count + ' of ' + response.hits.total);
        }

        if(hit._index.match(/v1/)) {
          callback(null);
          return;
        }

        logCleaner.url(hit._source);
        logCleaner.user(hit._source, { force: true }, function() {
          var index = hit._index.replace(/api-umbrella-logs-/, 'api-umbrella-logs-v1-' + config.environment + '-');
          indexes[hit._index] = index;

          bulkCommands.push({
            index: {
              _index: index,
              _type: hit._type,
              _id: hit._id,
            },
          });

          bulkCommands.push(hit._source);

          callback(null);
        });
      }, function() {
        elasticSearch.bulk({ body: bulkCommands }, function(error) {
          if(error) {
            console.error('INDEX ERROR', error);
          }

          console.info('Indexed ' + count + ' of ' + response.hits.total);

          if(count < response.hits.total) {
            elasticSearch.scroll({
              scrollId: response._scroll_id,
              scroll: '5m'
            }, getMoreUntilDone);
          } else {
            console.info('Sanity checks...');
            // Sleep to let the bulk indexing catch-up. Otherwise, the counts
            // on the new index can be off it seems.
            setTimeout(function() {
              async.eachSeries(Object.keys(indexes), function(oldIndex, callback) {
                var newIndex = indexes[oldIndex];

                elasticSearch.search({
                  index: oldIndex,
                  size: 1,
                  ignoreIndices: 'missing',
                  body: {
                    sort: [{ request_at: 'desc' }],
                    query: {
                      match_all: {},
                    },
                  },
                }, function(error, oldResponse) {
                  var oldTotal = oldResponse.hits.total;
                  var oldLastTime = oldResponse.hits.hits[0]._source.request_at;

                  elasticSearch.search({
                    index: newIndex,
                    size: 1,
                    ignoreIndices: 'missing',
                    body: {
                      sort: [{ request_at: 'desc' }],
                      query: {
                        match_all: {},
                      },
                    },
                  }, function(error, newResponse) {
                    var newTotal = newResponse.hits.total;
                    var newLastTime = newResponse.hits.hits[0]._source.request_at;
                    var deleteIndex = false;

                    if(oldTotal === newTotal && oldLastTime && oldLastTime === newLastTime) {
                      console.info(oldIndex + ' and ' + newIndex + ' match (' + newTotal + ' records - last record: ' + newLastTime + ')');
                      deleteIndex = true;
                    } else {
                      console.info('WARNING: ' + oldIndex + ' and ' + newIndex + ' DO NOT match (' + oldTotal + ' vs ' + newTotal + ' records)');
                      var todayIndex = 'api-umbrella-logs-' + moment().utc().format('YYYY-MM');
                      if(oldIndex === todayIndex && newTotal > oldTotal) {
                        console.info('  Continuing because it is the current month');
                        deleteIndex = true;
                      }
                    }

                    if(deleteIndex) {
                      elasticSearch.indices.delete({
                        index: oldIndex,
                      }, function(error) {
                        if(error && false) {
                          console.info('DELETE INDEX ERROR: ', error);
                          callback(null);
                        } else {
                          var readIndex = newIndex.replace(/-v1-/, '-');
                          var writeIndex = newIndex.replace(/v1/, 'write');
                          elasticSearch.indices.updateAliases({
                            body: {
                              actions: [
                                { add: { index: newIndex, alias: readIndex } },
                                { add: { index: newIndex, alias: writeIndex } },
                              ],
                            },
                          }, function(error) {
                            if(error) {
                              console.info('UPDATE ALIAS ERROR: ', error);
                            }

                            console.info('Optimizing ', newIndex);
                            elasticSearch.indices.optimize({
                              index: newIndex,
                              maxNumSegments: 1,
                            }, function(error) {
                              if(error) {
                                console.info('OPTIMIZE ALIAS ERROR: ', error);
                              }

                              console.info('Finished optimizing');
                              callback(null);
                            });
                          });
                        }
                      });
                    } else {
                      callback(null);
                    }
                  });
                });
              }, function() {
                console.info('Finished');
                done();
              });
            }, 5000);
          }
        });
      });
    });
  });
};

exports.rollback = function(client, done) {
	done();
};
