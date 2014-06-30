'use strict';

require('../test_helper');

var apiUmbrellaConfig = require('api-umbrella-config'),
    mongoose = require('mongoose'),
    path = require('path'),
    redis = require('redis');

var config = apiUmbrellaConfig.load(path.resolve(__dirname, '../config/test.yml'));

mongoose.testConnection = mongoose.createConnection();

// Drop the mongodb database.
before(function(done) {
  mongoose.testConnection.on('connected', function() {
    // Drop the whole database, since that properly blocks for any active
    // connections. The database will get re-created on demand.
    mongoose.testConnection.db.dropDatabase(done);
  });

  mongoose.testConnection.open(config.get('mongodb.url'), config.get('mongodb.options'));
});

// Wipe the redis data.
before(function(done) {
  global.redisClient = redis.createClient(config.get('redis'));
  global.redisClient.flushdb(done);
});

// Close the mongo connection cleanly after each run.
after(function(done) {
  mongoose.testConnection.close(done);
});
