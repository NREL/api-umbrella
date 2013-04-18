require('../test_helper');

mongoose.connect('mongodb://127.0.0.1:27017/api_umbrella_test');

require('../factories/api_users');

var redis = require('redis'),
    DatabaseCleaner = require('database-cleaner');

before(function(done) {
  var databaseCleaner = new DatabaseCleaner('mongodb');
  databaseCleaner.clean(mongoose.connection.db, function() {
    done();
  });
});

before(function(done) {
  var client = redis.createClient();

  var databaseCleaner = new DatabaseCleaner('redis');
  databaseCleaner.clean(client, function() {
    done();
  });
});
