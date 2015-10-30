'use strict';

require('../test_helper');

var mongoose = require('mongoose');

describe('boot', function() {
  it('generates the initial superusers with tokens', function(done) {
    mongoose.testConnection.model('Admin').find({}, function(error, admins) {
      should.not.exist(error);
      admins.length.should.eql(1);
      admins[0].username.should.eql('initial.admin@example.com');
      admins[0].superuser.should.eql(true);
      admins[0].id.should.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
      admins[0].authentication_token.should.match(/^[a-zA-Z0-9]{40}$/);
      done();
    });
  });
});
