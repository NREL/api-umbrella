'use strict';

var _ = require('lodash'),
    async = require('async'),
    config = require('api-umbrella-config').global(),
    events = require('events'),
    logger = require('../logger'),
    mongoConnect = require('../mongo_connect'),
    rateLimitModel = require('../models/rate_limit_model'),
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
var Worker = function() {
  this.initialize.apply(this, arguments);
};

module.exports.Worker = Worker;

util.inherits(Worker, events.EventEmitter);
_.extend(Worker.prototype, {
  rateLimits: [],
  syncEvery: 500,

  // Use a small time buffer when performing the polling.
  //
  // Since our polling is based on the updated_at field set by each server when
  // updating a Mongo record, this buffer handles the possibility that some of
  // the different servers might have a small amount of clock skew, resulting
  // in updated_tat timestamps that don't line up when dealing with the same
  // record from different servers. This skew should hopefully be much, much
  // smaller if all the servers are properly setup with NTP, but this allows
  // for a bit of forgiveness.
  syncBuffer: 2000,

  initialize: function(options) {
    this.options = options || {};

    this.once('synced', function() {
      this.emit('ready');
    }.bind(this));

    async.parallel([
      this.connectMongo.bind(this),
      this.connectRedis.bind(this),
    ], this.handleConnections.bind(this));
  },

  connectMongo: function(asyncReadyCallback) {
    mongoConnect(asyncReadyCallback);
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
      logger.error('Distributed rate limits sync connections error: ', error);
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
      return {
        duration: options.duration,
        expireAfter: options.duration + options.accuracy + 1000,
        redisPrefix: options.limit_by + ':' + options.duration,
        mongoModel: rateLimitModel(options),
      };
    }.bind(this));
  },

  syncRateLimits: function() {
    async.each(this.rateLimits, this.syncRateLimitCollection.bind(this), this.finishedSyncRateLimits.bind(this));
  },

  syncRateLimitCollection: function(rateLimit, asyncCallback) {
    var since;
    if(this.lastSyncTime) {
      since = this.lastSyncTime - this.syncBuffer;
    } else {
      // If the data has not been synced yet, sync everything from the rate
      // limit's duration (eg, the past 1 hour for a 1 hour rate limit).
      since = new Date() - rateLimit.duration;
    }

    this.lastSyncTime = new Date();

    var stream = rateLimit.mongoModel.find({
      updated_at: { '$gte': new Date(since) },
    }).stream();

    var queue = async.queue(this.processSyncQueue.bind(this, rateLimit), 10);
    queue.drain = function() {
      asyncCallback(null);
    };

    var hasMongoResults = false;
    stream.on('data', function(mongoResult) {
      hasMongoResults = true;
      queue.push(mongoResult);
    });

    stream.on('error', function(error) {
      logger.error('Distributed rate limits sync MongoDB result error: ', error);
      asyncCallback(error);
    });

    stream.on('close', function() {
      // Call the callback if no mongo results were present (so queue.drain
      // will never be called).
      if(!hasMongoResults) {
        asyncCallback(null);
      }
    });
  },

  processSyncQueue: function(rateLimit, mongoResult, callback) {
    this.redis.get(mongoResult._id, function(error, redisCount) {
      if(error) {
        logger.error('Distributed rate limits sync Redis result error: ', error);
        callback(error);
        return false;
      }

      redisCount = parseInt(redisCount, 10);

      if(!redisCount) {
        this.redis.multi()
          .set(mongoResult._id, mongoResult.count)
          .pexpire(mongoResult._id, rateLimit.expireAfter)
          .exec(callback);

        logger.info('Syncing distributed rate limit: ' + mongoResult._id + ' = ' + mongoResult.count);
      } else if(mongoResult.count > redisCount) {
        var difference = mongoResult.count - redisCount;
        this.redis.incrby(mongoResult._id, difference, callback);

        logger.info('Syncing distributed rate limit: ' + mongoResult._id + ' += ' + difference);
      } else {
        callback(null);
      }
    }.bind(this));
  },

  finishedSyncRateLimits: function() {
    this.emit('synced');

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

    if(mongoose.connection) {
      mongoose.connection.close();
    }

    if(callback) {
      callback(null);
    }
  },
});
