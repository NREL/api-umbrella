'use strict';

require('../test_helper');

var mongoose = require('mongoose');

describe('boot', function() {
  it('generates the initial superusers with tokens', function(done) {
  this.timeout(9000000);
    mongoose.testConnection.model('Admin').find({}, function(error, admins) {
      should.not.exist(error);
      admins.length.should.eql(1);
      admins[0].authentication_token.should.match(/^[a-zA-Z0-9]{40}$/);
      done();
    });
  });
});
