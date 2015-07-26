'use strict';

require('../test_helper');

var async = require('async'),
    Factory = require('factory-lady'),
    moment = require('moment'),
    mongoose = require('mongoose'),
    request = require('request');

require('../../lib/models/rate_limit_model');
var RateLimit = mongoose.testConnection.model('RateLimit');

describe('distributed rate limit sync', function() {
  before(function(done) {
    // Since this is for testing the initial startup sync, we need to insert
    // this before calling runServer. For the rate limit inserts, we also give
    // it a sizable buffer (45 minutes ago on a 50 minute duration, so 5
    // minutes of buffer). This buffer ensures that the tests pass even if the
    // startup and other tests take a while to run before we explicitly test
    // against for the startup sync with this key.
    Factory.create('api_user', function(user) {
      this.apiKeyWithExistingCounts = user.api_key;

      var options = {
        apiKey: this.apiKeyWithExistingCounts,
        duration: 50 * 60 * 1000, // 50 minutes
        limit: 1001,
        updatedAt: new Date(moment().startOf('minute').toDate() - 45 * 60 * 1000), // 45min ago
      };

      setDistributedCount(97, options, function() {
        options.updatedAt = new Date(moment().startOf('minute').toDate() - 51 * 60 * 1000); // 51min ago
        setDistributedCount(41, options, done);
      });
    }.bind(this));
  });

  shared.runServer({
    apiSettings: {
      rate_limits: [
        {
          duration: 50 * 60 * 1000, // 50 minutes
          accuracy: 1 * 60 * 1000, // 1 minute
          limit_by: 'apiKey',
          limit: 1001,
          distributed: true,
          response_headers: true,
        },
      ],
    },
    apis: [
      {
        _id: 'example2',
        frontend_host: 'localhost',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9444,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/info/specific/',
            backend_prefix: '/info/specific/',
          },
        ],
        settings: {
          rate_limits: [
            {
              duration: 45 * 60 * 1000, // 45 minutes
              accuracy: 1 * 60 * 1000, // 1 minute
              limit_by: 'apiKey',
              limit: 1002,
              distributed: true,
              response_headers: true,
            }
          ],
        },
        sub_settings: [
          {
            http_method: 'any',
            regex: '^/info/specific/subsettings/',
            settings: {
              rate_limits: [
                {
                  duration: 48 * 60 * 1000, // 48 minutes
                  accuracy: 1 * 60 * 1000, // 1 minute
                  limit_by: 'apiKey',
                  limit: 1003,
                  distributed: true,
                  response_headers: true,
                }
              ],
            },
          },
          {
            http_method: 'any',
            regex: '^/info/specific/non-distributed/',
            settings: {
              rate_limits: [
                {
                  duration: 12 * 60 * 1000, // 12 minutes
                  accuracy: 1 * 60 * 1000, // 1 minute
                  limit_by: 'apiKey',
                  limit: 1004,
                  distributed: false,
                  response_headers: true,
                }
              ],
            },
          },
        ],
      },
      {
        _id: 'example',
        frontend_host: 'localhost',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9444,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/',
            backend_prefix: '/',
          },
        ],
      },
    ],
  });

  function makeRequests(numRequests, options, callback) {
    var totalLocalCount = 0;

    async.timesLimit(numRequests, 50, function(index, timesCallback) {
      var urlPath = options.urlPath || '/info/';
      request.get('http://localhost:9080' + urlPath + '?api_key=' + options.apiKey, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(200);

        var count = parseInt(response.headers['x-ratelimit-limit'], 10) - parseInt(response.headers['x-ratelimit-remaining'], 10);
        if(count > totalLocalCount) {
          totalLocalCount = count;
        }

        timesCallback();
      });
    }, function() {
      if(!options.disableCountCheck) {
        totalLocalCount.should.eql(numRequests);
      }

      // Delay the callback to give the local rate limits (from the actual
      // requests being made) a chance to be pushed into the distributed mongo
      // store.
      setTimeout(callback, 550);
    });
  }

  function setDistributedCount(count, options, callback) {
    var updatedAt = options.updatedAt || new Date();
    var bucketDate = moment(updatedAt).startOf('minute').toDate();
    var host = options.host || 'localhost';

    var key = 'apiKey:' + options.duration + ':' + options.apiKey + ':' + host + ':' + bucketDate.getTime();

    RateLimit.update({
      _id: key,
    }, {
      time: bucketDate,
      updated_at: updatedAt,
      count: count,
      expire_at: updatedAt.getTime() + 60 * 60 * 1000,
    }, { upsert: true }, function(error) {
      should.not.exist(error);

      // Delay the callback to give the distributed rate limit a chance to
      // propagate to the local nodes.
      setTimeout(callback, 550);
    });
  }

  function expectDistributedCountAfterSync(expectedCount, options, callback) {
    var pipeline = [
      {
        $match: { _id: new RegExp(':' + options.apiKey + ':') },
      },
      {
        $group: {
          _id: '$_id',
          count: { '$sum': '$count' },
        },
      },
    ];

    RateLimit.aggregate(pipeline, function(error, response) {
      var count = 0;
      if(response && response[0] && response[0].count) {
        count = response[0].count;
      }
      count.should.eql(expectedCount);

      callback();
    });
  }

  function expectLocalCountAfterSync(expectedCount, options, callback) {
    var urlPath = options.urlPath || '/info/';
    request.get('http://localhost:9080' + urlPath + '?api_key=' + options.apiKey, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);

      var limit = parseInt(response.headers['x-ratelimit-limit'], 10);
      limit.should.eql(options.limit);

      var count = limit - parseInt(response.headers['x-ratelimit-remaining'], 10);
      var previousCount = count - 1;
      previousCount.should.eql(expectedCount);

      callback();
    });
  }

  it('sets new rate limits to the distributed value', function(done) {
    var options = {
      apiKey: this.apiKey,
      duration: 50 * 60 * 1000, // 50 minutes
      limit: 1001,
    };

    setDistributedCount(143, options, function() {
      expectLocalCountAfterSync(143, options, done);
    });
  });

  it('increases existing rate limits to match the distributed value', function(done) {
    var options = {
      apiKey: this.apiKey,
      duration: 50 * 60 * 1000, // 50 minutes
      limit: 1001,
    };

    makeRequests(75, options, function() {
      setDistributedCount(99, options, function() {
        expectLocalCountAfterSync(99, options, done);
      });
    });
  });

  it('ignores rate limits when the distributed value is lower', function(done) {
    var options = {
      apiKey: this.apiKey,
      duration: 50 * 60 * 1000, // 50 minutes
      limit: 1001,
    };

    makeRequests(80, options, function() {
      setDistributedCount(60, options, function() {
        expectLocalCountAfterSync(80, options, done);
      });
    });
  });

  it('syncs local rate limits into mongo', function(done) {
    var options = {
      apiKey: this.apiKey,
      duration: 50 * 60 * 1000, // 50 minutes
      limit: 1001,
    };

    makeRequests(27, options, function() {
      expectDistributedCountAfterSync(27, options, done);
    });
  });

  it('does not sync non-distributed rate limits into mongo', function(done) {
    var options = {
      apiKey: this.apiKey,
      duration: 12 * 60 * 1000, // 12 minutes
      limit: 1004,
      urlPath: '/info/specific/non-distributed/',
    };

    makeRequests(47, options, function() {
      expectDistributedCountAfterSync(0, options, done);
    });
  });

  it('syncs api-specific rate limits', function(done) {
    var options = {
      apiKey: this.apiKey,
      duration: 45 * 60 * 1000, // 45 minutes
      limit: 1002,
      urlPath: '/info/specific/',
    };

    setDistributedCount(133, options, function() {
      expectLocalCountAfterSync(133, options, done);
    });
  });

  it('syncs api-specific sub settings rate limits', function(done) {
    var options = {
      apiKey: this.apiKey,
      duration: 48 * 60 * 1000, // 48 minutes
      limit: 1003,
      urlPath: '/info/specific/subsettings/',
    };

    setDistributedCount(38, options, function() {
      expectLocalCountAfterSync(38, options, done);
    });
  });

  it('performs a sync for the entire duration (but not outside the duration) on start', function(done) {
    var options = {
      apiKey: this.apiKeyWithExistingCounts,
      duration: 50 * 60 * 1000, // 50 minutes
      limit: 1001,
    };

    expectLocalCountAfterSync(97, options, done);
  });

  it('polls for distributed changes after start', function(done) {
    this.timeout(5000);

    var options = {
      apiKey: this.apiKey,
      duration: 50 * 60 * 1000, // 50 minutes
      limit: 1001,
    };

    var expectedCount = 9;
    makeRequests(9, options, function() {
      expectDistributedCountAfterSync(expectedCount, options, function() {
        expectLocalCountAfterSync(expectedCount, options, function() {
          options.disableCountCheck = true;
          makeRequests(10, options, function() {
            // The expected count is 20 due to the extra request made in
            // expectLocalCountAfterSync (9 + 10 + 1).
            expectedCount = 20;
            expectDistributedCountAfterSync(expectedCount, options, function() {
              expectLocalCountAfterSync(expectedCount, options, function() {

                // Delay the next override to give a chance for the request
                // made in expectLocalCountAfterSync above a chance to
                // propagate so that we can override it.
                setTimeout(function() {
                  setDistributedCount(77, options, function() {
                    expectDistributedCountAfterSync(77, options, function() {
                      expectLocalCountAfterSync(77, options, done);
                    });
                  });
                }, 550);
              });
            });
          });
        });
      });
    });
  });
});
