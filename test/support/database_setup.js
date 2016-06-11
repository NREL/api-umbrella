'use strict';

require('../test_helper');

var _ = require('lodash'),
    config = require('./config'),
    async = require('async'),
    elasticsearch = require('elasticsearch'),
    mongoose = require('mongoose');

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

// Wipe the elasticsearch data.
before(function elasticsearchOpen(done) {
  this.timeout(10000);

  // elasticsearch mutates the client config, so always work off a clone:
  // https://github.com/elasticsearch/elasticsearch-js/issues/33
  var clientConfig = _.cloneDeep(config.get('elasticsearch'));
  global.elasticsearch = new elasticsearch.Client(clientConfig);

  global.elasticsearch.search({
    index: 'api-umbrella-logs-*',
    allowNoIndices: true,
    type: 'log',
    q: '*'
  }, function(err, results) {
    if(err) {
      done(err);
    }
    async.map(results.hits.hits, function(hit, callback) {
      global.elasticsearch.delete({
        index: hit['_index'],
        type: hit['_type'],
        id: hit['_id']
      }, callback);
    }, done);
  });
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
