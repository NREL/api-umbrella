'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    request = require('request');

describe('failures', function() {
  shared.runServer({
    gatekeeper: {
      api_key_cache: false,
    },

    // Be sure that these tests interact with a backend published via Mongo,
    // so we can also catch errors for when the mongo-based configuration
    // data experiences failures.
    apis: [
      {
        _id: 'db-config',
        frontend_host: 'localhost',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9444,
          }
        ],
        url_matches: [
          {
            frontend_prefix: '/db-config/info/',
            backend_prefix: '/info/',
          }
        ],
      },
    ],
  }, {
    user: { settings: { rate_limit_mode: 'unlimited' } },
  });

  describe('mongodb', function() {
    it('does not drop connections during replicaset elections', function(done) {
      this.timeout(120000);

      // Perform parallel requests constantly in the background of this tests.
      // This ensures that no connections are dropped during any point of the
      // replicaset changes we'll make later on.
      var runTests = true;
      var testRunCount = 0;
      async.times(5, function(index, parallelNext) {
        async.whilst(function() {
          return runTests;
        }, function(whilstCallback) {
          request.get('http://localhost:9080/db-config/info/' + _.uniqueId(), this.options, function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            whilstCallback();
            testRunCount++;
          });
        }.bind(this), parallelNext);
      }.bind(this), function(error) {
        should.not.exist(error);

        // Sanity check to ensure our tests were valid and we weren't caching
        // the api key locally and not actually making any mongodb requests.
        async.series([
          function(next) {
            this.user.disabled_at = new Date();
            this.user.save(next);
          }.bind(this),
          function(next) {
            request.get('http://localhost:9080/db-config/info/' + _.uniqueId(), this.options, function(error, response, body) {
              should.not.exist(error);
              response.statusCode.should.eql(403);
              body.should.include('API_KEY_DISABLED');
              next();
            });
          }.bind(this),
        ], done);
      }.bind(this));

      var initialPrimaryReplicaId;
      var currentPrimaryReplicaId;
      var currentPrimaryServerId;
      function waitForPrimaryChange(callback) {
        var primaryChanged = false;
        async.doUntil(function(untilCallback) {
          request.get('http://127.0.0.1:13089/v1/replica_sets/test-cluster/primary', function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            var data = JSON.parse(body);
            var newPrimaryServerId = data['server_id'];
            if(newPrimaryServerId !== currentPrimaryServerId) {
              currentPrimaryServerId = newPrimaryServerId;
              currentPrimaryReplicaId = data['_id'];
              primaryChanged = true;
            }

            if(initialPrimaryReplicaId === undefined) {
              initialPrimaryReplicaId = data['_id'];
            }

            untilCallback();
          });
        }, function() {
          return primaryChanged;
        }, callback);
      }

      function waitForNumTests(count, callback) {
        var initialCount = testRunCount;
        async.until(function() {
          var numRun = (testRunCount - initialCount);
          return numRun > count;
        }, function(untilCallback) {
          setTimeout(untilCallback, 10);
        }, callback);
      }

      async.series([
        // Detect the initial primary server in the replicaset.
        function(next) {
          waitForPrimaryChange(next);
        },
        // Wait to ensure we perform some successful tests before beginning our
        // replicaset changes.
        function(next) {
          waitForNumTests(100, next);
        },
        // Force a change in the replicaset primary by downgrading the priority
        // of the current primary.
        function(next) {
          var options = {
            json: {
              rsParams: {
                priority: 0.01,
              },
            }
          };
          request.patch('http://127.0.0.1:13089/v1/replica_sets/test-cluster/members/' + currentPrimaryReplicaId, options, function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            next();
          });
        },
        // Ensure the replicaset primary did in fact change.
        function(next) {
          waitForPrimaryChange(next);
        },
        // Ensure we perform a number of tests against the new primary.
        function(next) {
          waitForNumTests(100, next);
        },
        // Force another change in the replicaset primary by stopping the
        // current primary.
        function(next) {
          var options = {
            json: {
              action: 'stop',
            }
          };
          request.post('http://127.0.0.1:13089/v1/servers/' + currentPrimaryServerId, options, function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            next();
          });
        },
        // Ensure the replicaset primary did in fact change.
        function(next) {
          waitForPrimaryChange(next);
        },
        // Ensure we perform a number of tests against the new primary.
        function(next) {
          waitForNumTests(100, next);
        },
        // Reset the MongoDB replicaset back to the normal state after the
        // tests are finished, so we don't leave it in a strange state for
        // subsequent tests.
        function(next) {
          var options = {
            json: {
              rsParams: {
                priority: 99,
              },
            }
          };
          request.patch('http://127.0.0.1:13089/v1/replica_sets/test-cluster/members/' + initialPrimaryReplicaId, options, function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            next();
          });
        },
        function(next) {
          var options = {
            json: {
              action: 'reset',
            }
          };
          request.post('http://127.0.0.1:13089/v1/replica_sets/test-cluster', options, function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            next();
          });
        },
      ], function(error) {
        should.not.exist(error);

        // Stop running the background test requests.
        runTests = false;
      });
    });
  });
});
