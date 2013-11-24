'use strict';

var _ = require('lodash'),
    async = require('async'),
    config = require('./config'),
    events = require('events'),
    logger = require('./logger'),
    MongoClient = require('mongodb').MongoClient,
    redis = require('redis'),
    util = require('util');

/**
 * Synchronize the local Redis rate limit information with the distributed rate
 * limit information from Mongo.
 *
 * A local Redis instance on each Gatekeeper server is responsible for the rate
 * limit data. For distributed rate limits (typically those that are are over
 * time spans > 5-10 seconds), we also store the rate limit information in our
 * Mongo cluster. The data in Mongo gets updated by all the Gatekeeper servers,
 * which makes it the true source of rate limit information if requests are
 * being distributed across multiple Gatekeeper servers.
 *
 * This process polls MongoDB for recent rate limit data changes and then
 * synchronizes that data with each local Redis instance. In effect, this
 * brings MongoDB's eventual consistency model to our local Redis stores for
 * rate limit data (with a small delay for polling). This optimizes the speed
 * of our rate limit lookups inside the proxy, since it only ever has to
 * perform local in-memory Redis lookups. This also means that the Redis
 * information can be slightly out of date if requests are being spread across
 * multiple Gatekeeper servers, but it should become eventually consistent.
 *
 * There might be a better way to handle distributed rate limits that should be
 * revisited if this gets any more complex (perhaps having Mongo local on each
 * Gatekeeper server and running the queries with "nearest" read preference?).
 */
var DistributedRateLimitsSync = function() {
  this.initialize.apply(this, arguments);
};

util.inherits(DistributedRateLimitsSync, events.EventEmitter);
_.extend(DistributedRateLimitsSync.prototype, {
  rateLimits: [],
  syncEvery: 500,
  syncBuffer: 2000,

  /*
  redisScript: 'local id = KEYS[1] \
    local distributedCount = tonumber(ARGV[1]) \
    local expireAfter = tonumber(ARGV[2]) \
    local localCount = tonumber(redis.call("GET", id)) \
    if not localCount or distributedCount > localCount then \
      redis.call("SET", id, distributedCount) \
      redis.call("PEXPIRE", id, expireAfter) \
      return redis.status_reply("Set Limit " .. id .. " " .. localCount .. " => " .. distributedCount) \
    else \
      return redis.status_reply("Left Limit") \
    end',
  */

  initialize: function() {
    async.parallel([
      this.connectMongo.bind(this),
      this.connectRedis.bind(this),
    ], this.handleConnections.bind(this));
  },

  connectMongo: function(asyncReadyCallback) {
    MongoClient.connect(config.get('mongodb'), this.handleConnectMongo.bind(this, asyncReadyCallback));
  },

  handleConnectMongo: function(asyncReadyCallback, error, db) {
    if(!error) {
      this.mongo = db;
      asyncReadyCallback(null);
    } else {
      asyncReadyCallback(error);
    }
  },

  connectRedis: function(asyncReadyCallback) {
    this.redis = redis.createClient(config.get('redis'));

    this.redis.on('error', function(error) {
      asyncReadyCallback(error);
    });

    this.redis.on('ready', function() {
      asyncReadyCallback(null);
    });
  },

  handleConnections: function(error) {
    if(error) {
      logger.error(error);
      process.exit(1);
      return false;
    }

    this.refreshCollections();
    config.on('reload', this.refreshCollections.bind(this));

    this.syncRateLimits();
  },

  refreshCollections: function() {
    var rateLimits = [];

    var globalLimits = config.get('apiSettings.rate_limits');
    if(globalLimits) {
      rateLimits = rateLimits.concat(globalLimits);
    }

    var apis = config.get('apis');
    if(apis) {
      for(var i = 0; i < apis.length; i++) {
        var api = apis[i];

        if(api.settings && api.settings.rate_limits) {
          rateLimits = rateLimits.concat(api.settings.rate_limits);
        }

        if(api.sub_settings) {
          for(var j = 0; j < api.sub_settings.length; j++) {
            var subSettings = api.sub_settings[j];

            if(subSettings.settings && subSettings.settings.rate_limits) {
              rateLimits = rateLimits.concat(subSettings.settings.rate_limits);
            }
          }
        }
      }
    }

    rateLimits = _.uniq(rateLimits, function(options) {
      return options.limit_by + ':' + options.duration;
    });

    rateLimits = _.filter(rateLimits, function(options) {
      return (options.distributed === true);
    });

    this.rateLimits = _.map(rateLimits, function(options) {
      var prefix = options.limit_by + ':' + options.duration;
      return {
        expireAfter: options.duration + options.accuracy + 1000,
        redisPrefix: prefix,
        mongoCollection: this.mongo.collection('rate_limits_' + prefix.replace(/:/, '_')),
      };
    }.bind(this));
  },

  syncRateLimits: function() {
    this.lastSyncTime = new Date();

    async.each(this.rateLimits, this.syncRateLimitCollection.bind(this), this.finishedSyncRateLimits.bind(this));
  },

  syncRateLimitCollection: function(rateLimit, asyncCallback) {
    var since = this.lastSyncTime - this.syncEvery - this.syncBuffer;

    rateLimit.mongoCollection.find({
      updated_at: { '$gte': new Date(since) },
    }).each(function(error, mongoResult) {
      if(error) {
        logger.error(error);
        asyncCallback(error);
        return false;
      }

      if(mongoResult) {
        this.redis.get(mongoResult._id, function(error, redisCount) {
          if(error) {
            logger.error(error);
            return false;
          }

          redisCount = parseInt(redisCount, 10);

          if(!redisCount) {
            this.redis.multi()
              .set(mongoResult._id, mongoResult.count)
              .pexpire(this.getCurrentBucketKey(), this.timeWindow.expireAfter)
              .exec();

            logger.info('Syncing distributed rate limit: ' + mongoResult._id + ' = ' + mongoResult.count);
          } else if(mongoResult.count > redisCount) {
            var difference = mongoResult.count - redisCount;
            this.redis.incrby(mongoResult._id, difference);

            logger.info('Syncing distributed rate limit: ' + mongoResult._id + ' += ' + difference);
          }
        }.bind(this));

        /*
        console.info([mongoResult._id, mongoResult.count, rateLimit.expireAfter]);
        this.redis.eval(this.redisScript, 1, mongoResult._id, mongoResult.count, rateLimit.expireAfter, function(error, result) {
          console.info('EVALED ', arguments);
        });
        */
        
      } else {
        asyncCallback(null);
      }
    }.bind(this));
  },

  finishedSyncRateLimits: function() {
    var syncAgainIn = this.syncEvery;

    // If the sync took longer than the syncEvery to complete, go ahead and
    // sync again immediately.
    var now = new Date();
    if((now - this.lastSyncTime) > syncAgainIn) {
      syncAgainIn = 0;
    }

    this.syncRateLimitsTimeout = setTimeout(this.syncRateLimits.bind(this), syncAgainIn);
  },

  close: function(callback) {
    if(this.syncRateLimitsTimeout) {
      clearTimeout(this.syncRateLimitsTimeout);
    }

    if(callback) {
      callback(null);
    }
  },
});

module.exports.DistributedRateLimitsSync = DistributedRateLimitsSync;
