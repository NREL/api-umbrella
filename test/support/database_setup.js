'use strict';

require('../test_helper');

mongoose.connect('mongodb://127.0.0.1:27017/api_umbrella_test');
var redis = require('redis');

// Drop the mongodb database.
before(function(done) {
  mongoose.connection.on('connected', function() {
    // Drop the whole database, since that properly blocks for any active
    // connections. The database will get re-created on demand.
    mongoose.connection.db.dropDatabase(function() {
      done();
    });
  });
});

// Wipe the redis data.
before(function(done) {
  var client = redis.createClient();
  client.flushdb(function() {
    client.quit(function() {
      done();
    });
  });
});

// Close the mongo connection cleanly after each run.
after(function(done) {
  mongoose.connection.close(function() {
    done();
  });
});
