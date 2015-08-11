'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    execFile = require('child_process').execFile,
    Factory = require('factory-lady'),
    request = require('request');

describe('failures', function() {
  shared.runServer();

  describe('mongodb', function() {
    before(function fetchMongoDbReplicaSetInfo(done) {
      // Fetch the replicaset information from the mongo-orchestration.
      request.get('http://127.0.0.1:13089/v1/replica_sets/test-cluster', function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);

        // Put together a replicaset connection argument for passing to the
        // "--host" arg of the "mongo" command line tool (the syntax is a bit
        // different from the URL mongo-orchestration returns).
        this.hostArg = data.id + '/' + _.map(data.members, function(member) {
          return member.host;
        }).join(',');

        done();
      }.bind(this));
    });

    before(function publishDbConfig(done) {
      this.timeout(10000);

      // Be sure that these tests interact with a backend published via Mongo,
      // so we can also catch errors for when the mongo-based configuration
      // data experiences failures.
      shared.setDbConfigOverrides({
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
      }, function(error) {
        should.not.exist(error);
        shared.waitForConfig(done);
      });
    });

    beforeEach(function setOptionDefaults() {
      this.options = {
        headers: {
        },
        agentOptions: {
          maxSockets: 500,
        },
      };
    });

    after(function resetMongoDbReplicaSet(done) {
      this.timeout(10000);

      // Reset the MongoDB replicaset back to the normal state after the tests
      // are finished, so we don't leave it in a strange state for subsequent
      // tests.
      var options = {
        json: {
          action: 'reset',
        }
      };
      request.post('http://127.0.0.1:13089/v1/replica_sets/test-cluster', options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(200);

        // Not entirely sure if this is necessary, but wait a little while
        // after resetting, to ensure the replicaset has time to deal with
        // elections back to the normal state.
        setTimeout(done, 7000);
      }.bind(this));
    });

    after(function removeDbConfig(done) {
      // Longer timeout for our tests that change the mongodb primary server,
      // since we have to allow time for this local test connection to
      // reconnect to the primary.
      this.timeout(60000);

      // Remove DB-based config after these tests, so the rest of the tests go
      // back to the file-based configs.
      shared.revertDbConfigOverrides(function(error) {
        should.not.exist(error);
        shared.waitForConfig(done);
      });
    });

    it('does not drop connections during replicaset elections', function(done) {
      this.timeout(90000);

      var apiKeyBatches = {};
      var options = this.options;

      function makeBatch(apiKeys, callback) {
        async.eachSeries(apiKeys, function(apiKey, next) {
          request.get('http://localhost:9080/db-config/info/?api_key=' + apiKey, options, function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            setTimeout(next, 10);
          });
        }, callback);
      }

      async.series([
        // Generate batches of unique API keys. Each test will do something to
        // the replicaset, and then ensure nothing bad happens. Each API key
        // tested should be unique, so that we're sure we're not relying on any
        // API key caches. We run a batch of 100 different keys on each change
        // just to ensure things remain up across all workers for a bit of
        // time.
        function(callback) {
          async.timesSeries(3, function(batchIndex, batchNext) {
            apiKeyBatches[batchIndex] = [];

            async.times(100, function(index, next) {
              Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
                apiKeyBatches[batchIndex].push(user.api_key);
                next();
              });
            }, batchNext);
          }, callback);
        },

        // Make an initial batch of requests just to ensure things are working
        // as expected.
        function(callback) {
          makeBatch(apiKeyBatches[0], callback);
        },

        // Force the primary mongo host to step down for 30 seconds. (We do
        // this via the command line instead of mongo-orchestration's API,
        // since mongo-orchestration forces a 60 second step down period, and
        // we want something shorter).
        function(callback) {
          execFile('mongo', ['--host', this.hostArg, '--eval', 'rs.stepDown(30)'], function() {
            callback();
          });
        }.bind(this),

        // Run another batch of requests with the previous primary stepped
        // down. Requests may be returned more slowly while things wait for the
        // replicaset election to kick in, but no connections should fail.
        function(callback) {
          makeBatch(apiKeyBatches[1], callback);
        },

        // Force the new primary server offline completely. Just another sanity
        // check that a true failure and election will be handled properly.
        function(callback) {
          execFile('mongo', ['--host', this.hostArg, '--eval', 'db.shutdownServer({ force: true })', 'admin'], function(error) {
            callback(error);
          });
        }.bind(this),

        // Run the next batch of requests that should succeed.
        function(callback) {
          makeBatch(apiKeyBatches[2], callback);
        },
      ], done);
    });
  });
});
