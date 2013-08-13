'use strict';

var _ = require('underscore'),
    async = require('async'),
    i18n = require('i18n');

var TimeWindow = function() {
  this.initialize.apply(this, arguments);
};

_.extend(TimeWindow.prototype, {
  initialize: function(proxy, options) {
    this.proxy = proxy;
    this.options = options;

    this.expireAfter = options.duration + options.accuracy + 1000;
    this.numBuckets = Math.round(options.duration / options.accuracy);
    this.prefix = options.limit_by + ':' + options.duration;

    if(options.distributed) {
      this.mongoCollection  = this.proxy.mongo.collection('rate_limits_' + this.prefix.replace(/:/, '_'));

      this.mongoCollection.ensureIndex({ time: 1 },
        {
          background: true,
          expireAfterSeconds: this.expireAfter / 1000
        },
        function(error) {
          if(error) {
            console.error(error);
            return false;
          }
        });
    }
  },
});

var RateLimitRequestTimeWindow = function() {
  this.initialize.apply(this, arguments);
};

_.extend(RateLimitRequestTimeWindow.prototype, {
  initialize: function(rateLimitRequest, timeWindow, asyncRequestCallback) {
    this.timeWindow = timeWindow;
    this.proxy = rateLimitRequest.rateLimit.proxy;
    this.request = rateLimitRequest.request;
    this.response = rateLimitRequest.response;
    this.asyncRequestCallback = asyncRequestCallback;

    this.time = new Date().getTime();

    this.redisSum = 1;
    this.mongoSum = 1;

    if(this.timeWindow.options.distributed) {
      async.parallel([
        this.performRedisRateLimit.bind(this),
        this.syncMongoRateLimits.bind(this),
      ], this.handleDistributedSync.bind(this));
    } else {
      this.performRedisRateLimit(null);
    }
  },

  performRedisRateLimit: function(asyncFetchCallback) {
    this.proxy.redis.mget(this.getDurationBucketKeys(), this.handleRedisResponse.bind(this, asyncFetchCallback));
  },

  handleRedisResponse: function(asyncFetchCallback, error, replies) {
    if(error) {
      console.error(error);
      return false;
    }

    for(var i = 0, len = replies.length; i < len; i++) {
      var value = replies[i];
      if(value) {
        this.redisSum += parseInt(value, 10);
      }
    }

    var limit = this.timeWindow.options.limit;
    var remaining = limit - this.redisSum;
    if(remaining < 0) {
      remaining = 0;
    }

    if(this.timeWindow.options.response_headers) {
      this.response.setHeader('X-RateLimit-Limit', limit);
      this.response.setHeader('X-RateLimit-Remaining', remaining);
    }

    if(this.redisSum > this.timeWindow.options.limit) {
      this.asyncRequestCallback('Over Limit', this);
    } else {
      this.asyncRequestCallback(null, this);
    }

    if(asyncFetchCallback) {
      asyncFetchCallback(null);
    }
  },

  increment: function() {
    this.incrementRedis();
    if(this.timeWindow.options.distributed) {
      this.incrementMongo();
    }
  },

  incrementRedis: function() {
    this.proxy.redis.multi()
      .incr(this.getCurrentBucketKey())
      .pexpire(this.getCurrentBucketKey(), this.timeWindow.expireAfter)
      .exec(this.handleIncrementRedis);
  },

  handleIncrementRedis: function(error) {
    if(error) {
      console.error(error);
      return false;
    }
  },

  incrementMongo: function() {
    this.timeWindow.mongoCollection.update({
        _id: this.getCurrentBucketKey(),
        time: this.getCurrentBucketDate()
      },
      { '$inc': { count: 1 } },
      { upsert: true },
      this.handleIncrementMongo);
  },

  handleIncrementMongo: function(error) {
    if(error) {
      console.error(error);
      return false;
    }
  },

  syncMongoRateLimits: function(asyncFetchCallback) {
    this.timeWindow.mongoCollection.find({
      _id: { '$in': this.getDurationBucketKeys() },
    }).each(this.handleMongoRecord.bind(this, asyncFetchCallback));
  },

  handleMongoRecord: function(asyncFetchCallback, error, record) {
    if(error) {
      console.error(error);
      return false;
    }

    if(record) {
      this.mongoSum += record.count;
    } else {
      asyncFetchCallback(null);
    }
  },

  handleDistributedSync: function(error) {
    if(error) {
      console.error(error);
      return false;
    }

    if(this.mongoSum !== this.redisSum) {
      console.info('DIFFERENCE!');
      console.info('REDIS SUM: ', this.redisSum);
      console.info('MONGO SUM: ', this.mongoSum);
    }

    if(this.mongoSum > this.redisSum) {
      var difference = this.mongoSum - this.redisSum;

      this.proxy.redis.incrby(this.getCurrentBucketKey(), difference);
    }
  },

  getKey: function() {
    if(!this.key) {
      var limitBy = this.timeWindow.options.limit_by;

      if(this.request.apiUmbrellaGatekeeper.user.throttle_by_ip) {
        limitBy = 'ip';
      }

      this.key = this.timeWindow.prefix + ':';
      switch(limitBy) {
      case 'api_key':
        this.key += this.request.apiUmbrellaGatekeeper.apiKey;
        break;
      case 'ip':
        this.key += this.request.ip;
        break;
      }
    }

    return this.key;
  },

  getCurrentBucketKey: function() {
    if(!this.currentBucketKey) {
      this.currentBucketKey = this.getKey() + ':' + this.getCurrentBucketDate().toISOString();
    }

    return this.currentBucketKey;
  },

  getCurrentBucketTime: function() {
    if(!this.currentBucketTime) {
      this.currentBucketTime = Math.floor(this.time / this.timeWindow.options.accuracy) * this.timeWindow.options.accuracy;
    }

    return this.currentBucketTime;
  },

  getCurrentBucketDate: function() {
    if(!this.currentBucketDate) {
      this.currentBucketDate = new Date(this.getCurrentBucketTime());
    }

    return this.currentBucketDate;
  },

  getDurationBucketKeys: function() {
    if(!this.durationBucketKeys) {
      var key = this.getKey();
      this.durationBucketKeys = this.getDurationBucketDates().map(function(date) {
        return key + ':' + date.toISOString();
      });
    }

    return this.durationBucketKeys;
  },

  getDurationBucketDates: function() {
    if(!this.durationBucketDates) {
      this.durationBucketDates = [];
      for(var i = 0; i < this.timeWindow.numBuckets; i++) {
        this.durationBucketDates.push(new Date(this.getCurrentBucketTime() - this.timeWindow.options.accuracy * i));
      }
    }

    return this.durationBucketDates;
  },
});

var RateLimitRequest = function() {
  this.initialize.apply(this, arguments);
};

_.extend(RateLimitRequest.prototype, {
  initialize: function(rateLimit, request, response, next) {
    this.rateLimit = rateLimit;
    this.request = request;
    this.response = response;
    this.next = next;

    var env = process.env.NODE_ENV;

    // Allow a special header in non-production environments to bypass the
    // throttling for benchmarking purposes. Note that this is slightly
    // different than an unthrottled user account, since when fake throttling,
    // all the throttling logic will still be performed (just not enforced). An
    // unthrottled user account skips all the throttling logic, so for
    // benchmarking purposes it's not quite an exact comparison.
    this.fakeThrottling = false;
    if(env && env !== 'production' && this.request.headers['x-benchmark-fake-throttling'] === 'Yes') {
      this.fakeThrottling = true;
    }

    var requestTimeWindows = this.rateLimit.timeWindows.map(function(timeWindow) {
      return function(callback) {
        new RateLimitRequestTimeWindow(this, timeWindow, callback);
      }.bind(this);
    }.bind(this));

    async.parallel(requestTimeWindows, this.finished.bind(this));
  },

  finished: function(error, limitRequests) {
    if(error && !this.fakeThrottling) {
      this.response.statusCode = 429;
      this.response.end(i18n.__('over_rate_limit'));
    } else {
      this.next();

      for(var i = 0, len = limitRequests.length; i < len; i++) {
        limitRequests[i].increment();
      }
    }
  }
});

var RateLimit = function() {
  this.initialize.apply(this, arguments);
};

_.extend(RateLimit.prototype, {
  initialize: function(proxy, timeWindowOptions) {
    this.proxy = proxy;

    this.timeWindows = timeWindowOptions.map(function(options) {
      return new TimeWindow(this.proxy, options);
    }.bind(this));
  },

  handleRequest: function(request, response, next) {
    new RateLimitRequest(this, request, response, next);
  },
});

module.exports = function rateLimit(proxy, timeWindowOptions) {
  var middleware = new RateLimit(proxy, timeWindowOptions);
  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};
