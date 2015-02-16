'use strict';

require('../test_helper');

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    elasticsearch = require('elasticsearch'),
    mongoose = require('mongoose'),
    path = require('path');

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

after(function elasticsearchClose() {
  if(global.elasticsearch) {
    global.elasticsearch.close();
  }
});
