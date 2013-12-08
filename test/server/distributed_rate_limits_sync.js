'use strict';

require('../test_helper');

var async = require('async'),
    moment = require('moment'),
    rateLimitModel = require('../../lib/models/rate_limit_model');

describe('distributed rate limit sync', function() {
  var configOptions = {
    apiSettings: {
      rate_limits: [
        {
          duration: 59 * 60 * 1000, // 59 minutes
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

  before(function(done) {
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
    ];

    async.each(limits, function(limit, eachCallback) {
      var key = limit.options.limit_by + ':' + limit.options.duration + ':' + limit.key + ':' + this.bucketDate.toISOString();
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
            time: this.bucketDate,
            updated_at: new Date(),
            count: limit.distributedCount,
          }).save(callback);
        }.bind(this),
      ], eachCallback);
    }.bind(this), done);
  });

  shared.runDistributedRateLimitsSync(configOptions);

  it('sets new rate limits to the distributed value', function(done) {
    redisClient.get('apiKey:3540000:NEW:' + this.bucketDate.toISOString(), function(error, limit) {
      limit.should.eql('143');
      done();
    });
  });

  it('increases existing rate limits to match the distributed value', function(done) {
    redisClient.get('apiKey:3540000:EXISTING:' + this.bucketDate.toISOString(), function(error, limit) {
      limit.should.eql('99');
      done();
    });
  });

  it('ignores rate limits when the distributed value is lower', function(done) {
    redisClient.get('apiKey:3540000:LOWER:' + this.bucketDate.toISOString(), function(error, limit) {
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
});
