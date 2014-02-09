'use strict';

require('../test_helper');

var async = require('async'),
    config = require('../../gatekeeper/lib/config'),
    redis = require('redis'),
    net = require('net'),
    spawn = require('child_process').spawn;

mongoose.testConnection = mongoose.createConnection(config.get('mongodb'), config.get('mongodb_options'));

// Drop the mongodb database.
before(function(done) {
  mongoose.testConnection.on('connected', function() {
    // Drop the whole database, since that properly blocks for any active
    // connections. The database will get re-created on demand.
    mongoose.testConnection.db.dropDatabase(function() {
      done();
    });
  });
});

// Spin up a new redis-server for running the test suite. Multiple database on
// the main instance would be an option, but that seems like it may become
// deprecated. This also ensures our tests don't accidentally step on a
// person's local usage of any random database on the main redis instance.
var redisServer;
before(function(done) {
  // Spin up the redis-server process.
  redisServer = spawn('redis-server', ['--port', config.get('redis.port')]);

  // Ensure that the process is killed when the tests end.
  process.on('exit', function () {
    redisServer.kill('SIGKILL');
  });

  // Wait until we're able to establish a connection before moving on.
  var connected = false;
  async.until(function() {
    return connected;
  }, function(callback) {
    net.connect({
      port: config.get('redis.port'),
    }).on('connect', function() {
      connected = true;
      callback();
    }).on('error', function() {
      setTimeout(callback, 20);
    });
  }, done);
});

// Wipe the redis data.
before(function(done) {
  global.redisClient = redis.createClient(config.get('redis'));
  global.redisClient.flushdb(function() {
    done();
  });
});

// Close the mongo connection cleanly after each run.
after(function(done) {
  mongoose.testConnection.close(function() {
    done();
  });
});

after(function(done) {
  global.redisClient.quit(function() {
    redisServer.on('exit', function() {
      done();
    });

    // Attempt to gracefully shutdown.
    redisServer.kill('SIGTERM');
  });
});
