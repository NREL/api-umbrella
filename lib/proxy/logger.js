var _ = require('underscore'),
    crypto = require('crypto'),
    URLSafeBase64 = require('urlsafe-base64');

var Logger = function() {
  this.initialize.apply(this, arguments);
}

module.exports.Logger = Logger;

_.extend(Logger.prototype, {
  initialize: function(redis) {
    this.redis = redis;
  },

  push: function(uid, source, data, processAt) {
    if(!uid) {
      uid = Date.now().toString() + '-' + Math.random().toString();
    }

    var id = URLSafeBase64.encode(crypto.createHash('sha256').update(uid).digest('base64'));

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
    this.redis.del('log:' + id);
  },
});
