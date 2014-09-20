'use strict';

var _ = require('lodash'),
    simpleflake = require('simpleflake');

var Logger = function() {
  this.initialize.apply(this, arguments);
};

module.exports.Logger = Logger;

_.extend(Logger.prototype, {
  initialize: function(redis) {
    this.redis = redis;
  },

  push: function(uid, source, data, processAt) {
    var id = uid;
    if(!id) {
      id = simpleflake().toString('base58');
      if(process.env.NODE_ENV !== 'test') {
        console.error('Missing unique request ID for logging. This should not occur. Make sure the "X-Api-Umbrella-UID" HTTP header is present. Generated temporary ID: ' + id);
      }
    }

    if(!processAt) {
      processAt = Date.now() + 15 * 1000;
    }

    this.redis.multi()
      .hset('log:' + id, source, data)
      .zadd('log_jobs', processAt, id)
      .exec();
  },

  fetchJobs: function(callback) {
    this.redis.zrangebyscore('log_jobs', '-inf', Date.now(), callback);
  },

  deleteJob: function(id, callback) {
    this.redis.zrem('log_jobs', id, callback);
  },

  fetchLog: function(id, callback) {
    this.redis.hgetall('log:' + id, callback);
  },

  deleteLog: function(id, callback) {
    this.redis.del('log:' + id, callback);
  },
});
