'use strict';

require('../test_helper');

var apiUmbrellaConfig = require('api-umbrella-config'),
    elasticsearch = require('elasticsearch'),
    mongoose = require('mongoose'),
    path = require('path'),
    redis = require('redis');

var config = apiUmbrellaConfig.load(path.resolve(__dirname, '../config/test.yml'));

mongoose.testConnection = mongoose.createConnection();

// Drop the mongodb database.
before(function mongoOpen(done) {
  mongoose.testConnection.on('connected', function() {
    // Drop the whole database, since that properly blocks for any active
    // connections. The database will get re-created on demand.
    mongoose.testConnection.db.dropDatabase(done);
  });

  mongoose.testConnection.open(config.get('mongodb.url'), config.get('mongodb.options'));
});

// Wipe the redis data.
before(function redisOpen(done) {
  global.redisClient = redis.createClient(config.get('redis.port'), config.get('redis.host'));
  global.redisClient.flushdb(done);
});

// Wipe the elasticsearch data.
before(function elasticsearchOpen(done) {
  this.timeout(10000);

  global.elasticsearch = new elasticsearch.Client(config.get('elasticsearch'));
  global.elasticsearch.deleteByQuery({
    index: 'api-umbrella-logs-*',
    allowNoIndices: true,
    type: 'log',
    q: '*',
  }, done);
});

// Close the mongo connection cleanly after each run.
after(function mongoClose(done) {
  mongoose.testConnection.close(done);
});

after(function redisClose() {
  if(global.redisClient && global.redisClient.connected) {
    global.redisClient.end();
  }
});

after(function elasticsearchClose() {
  if(global.elasticsearch) {
    global.elasticsearch.close();
  }
});
