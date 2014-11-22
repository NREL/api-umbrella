'use strict';

require('../test_helper');

var async = require('async'),
    moment = require('moment'),
    mongoose = require('mongoose'),
    rateLimitModel = require('../../lib/models/rate_limit_model');

describe('distributed rate limit sync', function() {
  var configOptions = {
    apiSettings: {
      rate_limits: [
        {
          duration: 50 * 60 * 1000, // 50 minutes
          accuracy: 1 * 60 * 1000, // 1 minute
          limit_by: 'apiKey',
          limit: 10,
          distributed: true,
          response_headers: true,
        },
        {
          duration: 12 * 60 * 1000, // 12 minutes
          accuracy: 1 * 60 * 1000, // 1 minute
          limit_by: 'apiKey',
          limit: 10,
          distributed: false,
          response_headers: false,
        }
      ],
    },
    apis: [
      {
        settings: {
          rate_limits: [
            {
              duration: 45 * 60 * 1000, // 45 minutes
              accuracy: 1 * 60 * 1000, // 1 minute
              limit_by: 'apiKey',
              limit: 3,
              distributed: true,
              response_headers: true,
            }
          ],
        },
        sub_settings: [
          {
            settings: {
              rate_limits: [
                {
                  duration: 48 * 60 * 1000, // 48 minutes
                  accuracy: 1 * 60 * 1000, // 1 minute
                  limit_by: 'apiKey',
                  limit: 7,
                  distributed: true,
                  response_headers: true,
                }
              ],
            },
          },
        ],
      },
    ],
  };

  before(function setupDefaultRateLimits(done) {
    this.bucketDate = moment().startOf('minute').toDate();

    var options = configOptions.apiSettings.rate_limits[0];
    var localOptions = configOptions.apiSettings.rate_limits[1];
    var apiOptions = configOptions.apis[0].settings.rate_limits[0];
    var apiSubSettingsOptions = configOptions.apis[0].sub_settings[0].settings.rate_limits[0];

    var limits = [
      {
        options: options,
        key: 'NEW',
        distributedCount: 143,
      },
      {
        options: options,
        key: 'EXISTING',
        localCount: 75,
        distributedCount: 99,
      },
      {
        options: options,
        key: 'LOWER',
        localCount: 80,
        distributedCount: 60,
      },
      {
        options: localOptions,
        key: 'LOCAL',
        localCount: 47,
        distributedCount: 55,
      },
      {
        options: apiOptions,
        key: 'API',
        distributedCount: 133,
      },
      {
        options: apiSubSettingsOptions,
        key: 'API_SUB_SETTINGS',
        distributedCount: 38,
      },
      {
        options: options,
        key: 'OLD',
        updatedAt: new Date(this.bucketDate - 49 * 60 * 1000), // 49min ago
        distributedCount: 97,
      },
      {
        options: options,
        key: 'TOO_OLD',
        updatedAt: new Date(this.bucketDate - 61 * 60 * 1000), // 51min ago
        distributedCount: 41,
      },
    ];

    async.each(limits, function(limit, eachCallback) {
      var updatedAt = limit.updatedAt || new Date();
      var bucketDate = moment(updatedAt).startOf('minute').toDate();

      var key = limit.options.limit_by + ':' + limit.options.duration + ':' + limit.key + ':' + bucketDate.toISOString();
      async.parallel([
        function(callback) {
          if(limit.localCount) {
            redisClient.set(key, limit.localCount, callback);
          } else {
            callback(null);
          }
        }.bind(this),
        function(callback) {
          var Model = mongoose.testConnection.model(rateLimitModel(limit.options).modelName);
          new Model({
            _id: key,
            time: bucketDate,
            updated_at: updatedAt,
            count: limit.distributedCount,
          }).save(callback);
        }.bind(this),
      ], eachCallback);
    }.bind(this), function(error) {
      done(error);
    });
  });

  shared.runDistributedRateLimitsSync(configOptions);

  it('sets new rate limits to the distributed value', function(done) {
    redisClient.get('apiKey:3000000:NEW:' + this.bucketDate.toISOString(), function(error, limit) {
      limit.should.eql('143');
      done();
    });
  });

  it('increases existing rate limits to match the distributed value', function(done) {
    redisClient.get('apiKey:3000000:EXISTING:' + this.bucketDate.toISOString(), function(error, limit) {
      limit.should.eql('99');
      done();
    });
  });

  it('ignores rate limits when the distributed value is lower', function(done) {
    redisClient.get('apiKey:3000000:LOWER:' + this.bucketDate.toISOString(), function(error, limit) {
      limit.should.eql('80');
      done();
    });
  });

  it('ignores non-distributed rate limits', function(done) {
    redisClient.get('apiKey:720000:LOCAL:' + this.bucketDate.toISOString(), function(error, limit) {
      limit.should.eql('47');
      done();
    });
  });

  it('syncs api-specific rate limits', function(done) {
    redisClient.get('apiKey:2700000:API:' + this.bucketDate.toISOString(), function(error, limit) {
      limit.should.eql('133');
      done();
    });
  });

  it('syncs api-specific sub settings rate limits', function(done) {
    redisClient.get('apiKey:2880000:API_SUB_SETTINGS:' + this.bucketDate.toISOString(), function(error, limit) {
      limit.should.eql('38');
      done();
    });
  });

  it('initially performs a sync for the entire duration on start', function(done) {
    var bucketDate = new Date(this.bucketDate - 49 * 60 * 1000); // 49min ago
    redisClient.get('apiKey:3000000:OLD:' + bucketDate.toISOString(), function(error, limit) {
      limit.should.eql('97');
      done();
    });
  });

  it('does not sync distributed rate limits outside the duration on start', function(done) {
    redisClient.keys('apiKey:3000000:TOO_OLD:*', function(error, keys) {
      keys.length.should.eql(0);
      done();
    });
  });

  it('polls for distributed changes after start', function(done) {
    var options = configOptions.apiSettings.rate_limits[0];
    var Model = mongoose.testConnection.model(rateLimitModel(options).modelName);
    var updatedAt = new Date();
    var bucketDate = moment(updatedAt).startOf('minute').toDate();
    var key = options.limit_by + ':' + options.duration + ':AFTER:' + bucketDate.toISOString();

    var distributed = new Model({
      _id: key,
      time: bucketDate,
      updated_at: updatedAt,
      count: 76,
    });

    distributed.save();
    setTimeout(function() {
      redisClient.get('apiKey:3000000:AFTER:' + bucketDate.toISOString(), function(error, limit) {
        limit.should.eql('76');

        distributed.count = 99;
        distributed.updated_at = new Date();
        distributed.save();

        setTimeout(function() {
          redisClient.get('apiKey:3000000:AFTER:' + bucketDate.toISOString(), function(error, limit) {
            limit.should.eql('99');
            done();
          });
        }, this.sync.syncEvery + 50);
      }.bind(this));
    }.bind(this), this.sync.syncEvery + 50);
  });

  it('polling continues when no data is present on a polling cycle', function(done) {
    this.timeout(5000);

    var options = configOptions.apiSettings.rate_limits[0];
    var Model = mongoose.testConnection.model(rateLimitModel(options).modelName);
    var updatedAt = new Date();
    var bucketDate = moment(updatedAt).startOf('minute').toDate();
    var key = options.limit_by + ':' + options.duration + ':POLL:' + bucketDate.toISOString();

    var distributed = new Model({
      _id: key,
      time: bucketDate,
      updated_at: updatedAt,
      count: 76,
    });

    distributed.save();
    setTimeout(function() {
      redisClient.get('apiKey:3000000:POLL:' + bucketDate.toISOString(), function(error, limit) {
        limit.should.eql('76');

        // Wait long enough to to hit a polling cycle outside the 2 second
        // buffer.
        var wait = this.sync.syncBuffer + this.sync.syncEvery + 50;
        setTimeout(function() {
          distributed.count = 99;
          distributed.updated_at = new Date();
          distributed.save();

          setTimeout(function() {
            redisClient.get('apiKey:3000000:POLL:' + bucketDate.toISOString(), function(error, limit) {
              limit.should.eql('99');
              done();
            });
          }, this.sync.syncEvery + 50);
        }.bind(this), wait);
      }.bind(this));
    }.bind(this), this.sync.syncEvery + 50);
  });


  it('uses a 2 second buffer when polling for changes to account for clock skew', function(done) {
    // Use the 2 second buffer time +/- 500ms to account for the fact that we
    // only poll every 500ms, so the 2s buffer is approximate.
    var options = configOptions.apiSettings.rate_limits[0];
    var Model = mongoose.testConnection.model(rateLimitModel(options).modelName);
    var updatedAt = new Date() - 1400;
    var bucketDate = moment(updatedAt).startOf('minute').toDate();
    var key = options.limit_by + ':' + options.duration + ':BUFFER:' + bucketDate.toISOString();

    var distributed = new Model({
      _id: key,
      time: bucketDate,
      updated_at: updatedAt,
      count: 13,
    });

    distributed.save();
    setTimeout(function() {
      redisClient.get('apiKey:3000000:BUFFER:' + bucketDate.toISOString(), function(error, limit) {
        limit.should.eql('13');

        distributed.count = 88;
        distributed.updated_at = new Date() - 2600;
        distributed.save();

        setTimeout(function() {
          redisClient.get('apiKey:3000000:BUFFER:' + bucketDate.toISOString(), function(error, limit) {
            limit.should.eql('13');
            done();
          });
        }, this.sync.syncEvery + 50);
      }.bind(this));
    }.bind(this), this.sync.syncEvery + 50);
  });
});
