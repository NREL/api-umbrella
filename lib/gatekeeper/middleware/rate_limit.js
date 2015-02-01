'use strict';

var _ = require('lodash'),
    async = require('async'),
    logger = require('../../logger'),
    rateLimitModel = require('../../models/rate_limit_model'),
    utils = require('../utils');

var TimeWindow = function() {
  this.initialize.apply(this, arguments);
};

_.extend(TimeWindow.prototype, {
  initialize: function(proxy, options) {
    this.options = options;

    this.expireAfter = options.duration + options.accuracy + 1000;
    this.numBuckets = Math.round(options.duration / options.accuracy);
    this.prefix = options.limit_by + ':' + options.duration;

    if(options.distributed) {
      this.mongoModel = rateLimitModel(options);
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

    var limitBy = this.timeWindow.options.limit_by;
    var user = this.request.apiUmbrellaGatekeeper.user;
    var anonymousRateLimitBehavior = this.request.apiUmbrellaGatekeeper.settings.anonymous_rate_limit_behavior;
    var authenticatedRateLimitBehavior = this.request.apiUmbrellaGatekeeper.settings.authenticated_rate_limit_behavior;
    if(limitBy === 'apiKey' && !user && anonymousRateLimitBehavior === 'ip_only') {
      this.asyncRequestCallback(null, this);
    } else if(limitBy === 'ip' && user && authenticatedRateLimitBehavior === 'api_key_only') {
      this.asyncRequestCallback(null, this);
    } else {
      this.performRedisRateLimit();
    }
  },

  performRedisRateLimit: function() {
    this.proxy.redis.mget(this.getDurationBucketKeys(), this.handleRedisResponse.bind(this));
  },

  handleRedisResponse: function(error, replies) {
    if(error) {
      logger.error({ err: error }, 'Redis response error');
      this.asyncRequestCallback('internal_server_error', this);
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
      this.asyncRequestCallback('over_rate_limit', this);
    } else {
      this.asyncRequestCallback(null, this);
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
      logger.error({ err: error }, 'Redis increment error');
      return false;
    }
  },

  incrementMongo: function() {
    var conditions = {
      _id: this.getCurrentBucketKey(),
      time: this.getCurrentBucketDate()
    };

    var update = {
      '$inc': { count: 1 },
      '$set': { updated_at: new Date() },
    };

    var options = { upsert: true };
    this.timeWindow.mongoModel.update(conditions, update, options, this.handleIncrementMongo);
  },

  handleIncrementMongo: function(error) {
    if(error) {
      logger.error({ err: error }, 'MongoDB increment error');
      return false;
    }
  },

  getKey: function() {
    if(!this.key) {
      var limitBy = this.timeWindow.options.limit_by;

      if(!this.request.apiUmbrellaGatekeeper.user || this.request.apiUmbrellaGatekeeper.user.throttle_by_ip) {
        limitBy = 'ip';
      }

      this.key = this.timeWindow.prefix + ':';
      switch(limitBy) {
      case 'apiKey':
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

    if(request.apiUmbrellaGatekeeper.settings.rate_limit_mode === 'unlimited') {
      this.next();
      return true;
    }

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

    var rateLimits = request.apiUmbrellaGatekeeper.settings.rate_limits;
    var requestTimeWindows = rateLimits.map(function(rateLimitOptions) {
      return function(callback) {
        var timeWindow = this.rateLimit.fetchTimeWindow(rateLimitOptions);
        new RateLimitRequestTimeWindow(this, timeWindow, function(error, limitRequest) {
          // Defer errors until the end by making them part of the result
          // object. This is because async.parallel normally short-circuits to
          // the error handler in the event any task errors. However, in our
          // case, we still want to handle each rate limit, even if one of them
          // is over the limit.
          //
          // This may eventually be made easier in async:
          // https://github.com/caolan/async/issues/334
          callback(null, {
            error: error,
            limitRequest: limitRequest,
          });
        });
      }.bind(this);
    }.bind(this));

    async.parallel(requestTimeWindows, this.finished.bind(this));
  },

  finished: function(error, results) {
    var deferredErrors = _.compact(_.pluck(results, 'error'));
    if(!error && deferredErrors.length > 0) {
      error = deferredErrors[0];
    }

    if(error && !this.fakeThrottling) {
      utils.errorHandler(this.request, this.response, error);
    } else {
      this.next();

      var limitRequests = _.pluck(results, 'limitRequest');
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
  timeWindows: {},

  initialize: function(proxy) {
    this.proxy = proxy;
  },

  handleRequest: function(request, response, next) {
    new RateLimitRequest(this, request, response, next);
  },

  fetchTimeWindow: function(rateLimitOptions) {
    // Cache a TimeWindow object based on these options values. These pieces
    // are the ones that actually affect how the TimeWindow object gets setup
    // (which rate limit collection it uses, etc).
    var key = [
      rateLimitOptions.duration,
      rateLimitOptions.accuracy,
      rateLimitOptions.limit_by,
      rateLimitOptions.distributed,
    ].join('-');

    var timeWindow = this.timeWindows[key];
    if(!this.timeWindows[key]) {
      timeWindow = new TimeWindow(this.proxy, rateLimitOptions);
      this.timeWindows[key] = timeWindow;
    }

    // Re-set all of our passed in options on the cached TimeWindow object.
    // This allows us to re-use TimeWindow objects for rate limits where only
    // the limit or response headers settings are different (which doesn't
    // actually affect the cached pieces inside TimeWindow).
    timeWindow.options = rateLimitOptions;

    return timeWindow;
  },
});

module.exports = function rateLimit(proxy) {
  var middleware = new RateLimit(proxy);

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};
