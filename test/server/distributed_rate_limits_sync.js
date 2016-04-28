'use strict';

require('../test_helper');

var async = require('async'),
    Factory = require('factory-lady'),
    moment = require('moment'),
    mongoose = require('mongoose'),
    request = require('request');

var RateLimit = mongoose.testConnection.model('RateLimit');

describe('distributed rate limit sync', function() {
  before(function preSetupRateLimits(done) {
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
        accuracy: 1 * 60 * 1000, // 1 minute
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
          {
            http_method: 'any',
            regex: '^/info/specific/long-duration-bucket/',
            settings: {
              rate_limits: [
                {
                  duration: 24 * 60 * 60 * 1000, // 1 day
                  accuracy: 60 * 60 * 1000, // 1 hour
                  limit_by: 'apiKey',
                  limit: 1005,
                  distributed: true,
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
      request.get('http://localhost:9080' + urlPath + '?api_key=' + options.apiKey + '&index=' + index + '&rand=' + Math.random(), options.requestOptions, function(error, response) {
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
        totalLocalCount.should.be.gte(numRequests - 1);
        totalLocalCount.should.be.lte(numRequests);

        if(totalLocalCount !== numRequests) {
          // In some rare situations our internal rate limit counters might be
          // off since we fetch all of our rate limits and then increment them
          // separately. The majority of race conditions should be solved, but
          // one known issue remains that may very rarely lead to this warning
          // (but we don't want to fail the whole test as long as it remains
          // rare). See comments in rate_limit.lua's increment_all_limits().
          console.warn('WARNING: X-RateLimit-Remaining header was off by 1. This should be very rare. Investigate if you see this with any regularity.');
        }
      }

      // Delay the callback to give the local rate limits (from the actual
      // requests being made) a chance to be pushed into the distributed mongo
      // store.
      setTimeout(callback, 550);
    });
  }

  function setDistributedCount(count, options, callback) {
    var updatedAt = options.updatedAt || new Date();
    var bucketDate = Math.floor(updatedAt.getTime() / options.accuracy) * options.accuracy;
    var host = options.host || 'localhost';

    var key = 'apiKey:' + options.duration + ':' + options.apiKey + ':' + host + ':' + bucketDate;

    Factory.create('rate_limit', {
      _id: key,
      count: count,
      expire_at: bucketDate + options.duration + 60 * 1000,
    }, function() {
      // Delay the callback to give the distributed rate limit a chance to
      // propagate to the local nodes.
      setTimeout(callback, 550);
    });
  }

  function expectDistributedCountAfterSync(expectedCount, options, callback) {
    var pipeline = [
      {
        $match: {
          _id: new RegExp(':' + options.apiKey + ':'),
          expire_at: { '$gte': new Date() },
        },
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
    request.get('http://localhost:9080' + urlPath + '?api_key=' + options.apiKey, options.requestOptions, function(error, response) {
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

  function expectDbRateLimitRecord(options, callback) {
    RateLimit.collection.findOne({ _id: new RegExp(':' + options.apiKey + ':') }, function(error, doc) {
      should.not.exist(error);
      doc.ts.should.be.an('object');
      doc.ts._bsontype.should.eql('Timestamp');
      doc.count.should.be.a('number');
      doc.expire_at.should.be.a('date');
      callback();
    });
  }

  it('sets new rate limits to the distributed value', function(done) {
    var options = {
      apiKey: this.apiKey,
      duration: 50 * 60 * 1000, // 50 minutes
      accuracy: 1 * 60 * 1000, // 1 minute
      limit: 1001,
    };

    setDistributedCount(143, options, function() {
      expectLocalCountAfterSync(143, options, done);
    });
  });

  it('increases existing rate limits to match the distributed value', function(done) {
    this.timeout(15000);

    var frozenTime = new Date();
    var options = {
      apiKey: this.apiKey,
      duration: 50 * 60 * 1000, // 50 minutes
      accuracy: 1 * 60 * 1000, // 1 minute
      limit: 1001,

      // Freeze the time to ensure that the makeRequests and
      // setDistributedCount calls both affect the same bucket (otherwise,
      // makeRequests could end up populating two buckets if these tests happen
      // to run across a minute boundary).
      updatedAt: frozenTime,
      requestOptions: {
        headers: { 'X-Fake-Time': frozenTime.getTime() },
      },
    };

    makeRequests(75, options, function() {
      setDistributedCount(99, options, function() {
        expectLocalCountAfterSync(99, options, done);
      });
    });
  });

  it('ignores rate limits when the distributed value is lower', function(done) {
    this.timeout(15000);

    var frozenTime = new Date();
    var options = {
      apiKey: this.apiKey,
      duration: 50 * 60 * 1000, // 50 minutes
      accuracy: 1 * 60 * 1000, // 1 minute
      limit: 1001,

      // Freeze the time to ensure that the makeRequests and
      // setDistributedCount calls both affect the same bucket (otherwise,
      // makeRequests could end up populating two buckets if these tests happen
      // to run across a minute boundary).
      updatedAt: frozenTime,
      requestOptions: {
        headers: { 'X-Fake-Time': frozenTime.getTime() },
      },
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
      accuracy: 1 * 60 * 1000, // 1 minute
      limit: 1001,
    };

    makeRequests(27, options, function() {
      expectDistributedCountAfterSync(27, options, done);
    });
  });

  it('sets the expected rate limit record after making requests', function(done) {
    var options = {
      apiKey: this.apiKey,
      duration: 50 * 60 * 1000, // 50 minutes
      accuracy: 1 * 60 * 1000, // 1 minute
      limit: 1001,
    };

    makeRequests(27, options, function() {
      expectDistributedCountAfterSync(27, options, function(error) {
        should.not.exist(error);
        expectDbRateLimitRecord(options, done);
      });
    });
  });

  it('sets the expected rate limit record when preseeding the database during tests', function(done) {
    var options = {
      apiKey: this.apiKey,
      duration: 50 * 60 * 1000, // 50 minutes
      accuracy: 1 * 60 * 1000, // 1 minute
      limit: 1001,
    };

    setDistributedCount(143, options, function() {
      expectDbRateLimitRecord(options, done);
    });
  });

  it('does not sync non-distributed rate limits into mongo', function(done) {
    var options = {
      apiKey: this.apiKey,
      duration: 12 * 60 * 1000, // 12 minutes
      accuracy: 1 * 60 * 1000, // 1 minute
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
      accuracy: 1 * 60 * 1000, // 1 minute
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
      accuracy: 1 * 60 * 1000, // 1 minute
      limit: 1003,
      urlPath: '/info/specific/subsettings/',
    };

    setDistributedCount(38, options, function() {
      expectLocalCountAfterSync(38, options, done);
    });
  });

  it('syncs local rate limits for longer duration buckets when requests take place in the past, but within bucket time', function(done) {
    var options = {
      apiKey: this.apiKey,
      duration: 24 * 60 * 60 * 1000, // 1 day
      accuracy: 60 * 60 * 1000, // 1 hour
      limit: 1005,
      urlPath: '/info/specific/long-duration-bucket/',
      requestOptions: {
        headers: { 'X-Fake-Time': Date.now() - 8 * 60 * 60 * 1000 },
      },
    };

    makeRequests(4, options, function() {
      expectDistributedCountAfterSync(4, options, done);
    });
  });

  it('does not sync local rate limits for longer duration buckets when requests take place prior to the bucket time', function(done) {
    var options = {
      apiKey: this.apiKey,
      duration: 24 * 60 * 60 * 1000, // 1 day
      accuracy: 60 * 60 * 1000, // 1 hour
      limit: 1005,
      urlPath: '/info/specific/long-duration-bucket/',
      requestOptions: {
        headers: { 'X-Fake-Time': Date.now() - 48 * 60 * 60 * 1000 },
      },
    };

    makeRequests(3, options, function() {
      expectDistributedCountAfterSync(0, options, done);
    });
  });

  it('performs a sync for the entire duration (but not outside the duration) on start', function(done) {
    var options = {
      apiKey: this.apiKeyWithExistingCounts,
      duration: 50 * 60 * 1000, // 50 minutes
      accuracy: 1 * 60 * 1000, // 1 minute
      limit: 1001,
    };

    expectLocalCountAfterSync(97, options, done);
  });

  it('polls for distributed changes after start', function(done) {
    this.timeout(15000);

    var frozenTime = new Date();
    var options = {
      apiKey: this.apiKey,
      duration: 50 * 60 * 1000, // 50 minutes
      accuracy: 1 * 60 * 1000, // 1 minute
      limit: 1001,

      // Freeze the time to ensure that the makeRequests and
      // setDistributedCount calls both affect the same bucket (otherwise,
      // makeRequests could end up populating two buckets if these tests happen
      // to run across a minute boundary).
      updatedAt: frozenTime,
      requestOptions: {
        headers: { 'X-Fake-Time': frozenTime.getTime() },
      },
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
