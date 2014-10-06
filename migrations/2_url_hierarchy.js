'use strict';

var async = require('async'),
    elasticSearchConnect = require('../lib/elasticsearch_connect'),
    logCleaner = require('../lib/log_processor/cleaner');

exports.migrate = function(client, done) {
  console.info('migrate!');
  elasticSearchConnect(function(error, elasticSearch, elasticSearchConnection) {
    var count = 0;
    var startTime;

    console.info('search!');
    elasticSearch.search({
      index: 'api-umbrella-logs-v1-*',
      search_type: 'scan',
      scroll: '5m',
      size: 250,
      body: {
        query: {
          match_all: {},
        },
        filter: {
          not: {
            exists: {
              field: "request_hierarchy",
            },
          },
        },
      },
    }, function getMoreUntilDone(error, response) {
      startTime = process.hrtime();

      if(error) {
        done(error);
      }
      var bulkCommands = [];
      async.each(response.hits.hits, function(hit, callback) {
        count++;

        if(count % 100 === 0) {
          console.info('  Processing ' + count + ' of ' + response.hits.total);
        }

        logCleaner.url(hit._source, function() {
          // Remove the old field hierarchy information was stored in.
          delete hit._source.request_path_hierarchy;

          var index = hit._index;

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
        function continueScroll() {
          elasticSearch.scroll({
            scrollId: response._scroll_id,
            scroll: '5m'
          }, getMoreUntilDone);
        }

        if(bulkCommands.length > 0) {
          elasticSearch.bulk({ body: bulkCommands, requestTimeout: 120000 }, function(error) {
            var elapsedTime = process.hrtime(startTime);

            if(error) {
              console.error('INDEX ERROR', error);
              elasticSearchConnection.close();
              done(error);
            }

            console.info((new Date()).toISOString() + ' Indexed ' + count + ' of ' + response.hits.total + ' (' + bulkCommands.length / 2 + ' records indexed in ' + elapsedTime[0] + ' seconds)');

            if(count < response.hits.total) {
              continueScroll();
            } else {
              elasticSearchConnection.close();
              done();
            }
          });
        } else {
          console.info('Skipping ' + count + ' of ' + response.hits.total);
          if(count < response.hits.total) {
            continueScroll();
          } else {
            elasticSearchConnection.close();
            done();
          }
        }
      });
    });
  });
};

exports.rollback = function(client, done) {
	done();
};
