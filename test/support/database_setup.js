'use strict';

require('../test_helper');

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    elasticsearch = require('elasticsearch'),
    mongoose = require('mongoose'),
    path = require('path'),
    redis = require('redis');

var config = apiUmbrellaConfig.load(path.resolve(__dirname, '../config/test.yml'));

mongoose.testConnection = mongoose.createConnection();

// Open the mongodb database.
before(function mongoOpen(done) {
  this.timeout(20000);

  // Since we're calling createConnection earlier on, and then opening the
  // connection here, we need to explicitly handle whether we should call
  // openSet for a replicaset based URL.
  if(/^.+,.+$/.test(config.get('mongodb.url'))) {
    mongoose.testConnection.openSet(config.get('mongodb.url'), config.get('mongodb.options'));
  } else {
    mongoose.testConnection.open(config.get('mongodb.url'), config.get('mongodb.options'));
  }

  done();
});

// Wipe the redis data.
before(function redisOpen(done) {
  global.redisClient = redis.createClient(config.get('redis.port'), config.get('redis.host'));
  global.redisClient.flushdb(done);
});

// Wipe the elasticsearch data.
before(function elasticsearchOpen(done) {
  this.timeout(10000);

  // elasticsearch mutates the client config, so always work off a clone:
  // https://github.com/elasticsearch/elasticsearch-js/issues/33
  var clientConfig = _.cloneDeep(config.get('elasticsearch'));
  global.elasticsearch = new elasticsearch.Client(clientConfig);
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
