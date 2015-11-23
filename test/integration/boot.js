'use strict';

require('../test_helper');

var mongoose = require('mongoose');

describe('boot', function() {
  var uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
  var apiKeyRegex = /^[a-zA-Z0-9]{40}$/;

  describe('database seeding', function() {
    it('generates the initial api key for the static site', function(done) {
      mongoose.testConnection.model('ApiUser').find({ email: 'static.site.ajax@internal.apiumbrella' }, function(error, users) {
        should.not.exist(error);
        users.length.should.eql(1);
        var user = users[0].toObject();
        user._id.should.match(uuidRegex);
        user.api_key.should.match(apiKeyRegex);
        user.email.should.eql('static.site.ajax@internal.apiumbrella');
        user.registration_source.should.eql('seed');
        user.roles.should.eql(['api-umbrella-key-creator', 'api-umbrella-contact-form']);
        user.settings._id.should.match(uuidRegex);
        user.settings.rate_limit_mode.should.eql('custom');
        user.settings.rate_limits.length.should.eql(2);
        user.settings.rate_limits[0]._id.should.match(uuidRegex);
        user.settings.rate_limits[0].duration.should.eql(60000);
        user.settings.rate_limits[0].accuracy.should.eql(5000);
        user.settings.rate_limits[0].limit_by.should.eql('ip');
        user.settings.rate_limits[0].limit.should.eql(5);
        user.settings.rate_limits[0].response_headers.should.eql(false);
        user.settings.rate_limits[1]._id.should.match(uuidRegex);
        user.settings.rate_limits[1].duration.should.eql(3600000);
        user.settings.rate_limits[1].accuracy.should.eql(60000);
        user.settings.rate_limits[1].limit_by.should.eql('ip');
        user.settings.rate_limits[1].limit.should.eql(20);
        user.settings.rate_limits[1].response_headers.should.eql(true);
        user.created_at.should.be.a('date');
        user.updated_at.should.be.a('date');
        done();
      });
    });

    it('generates the initial api key for the web admin', function(done) {
      mongoose.testConnection.model('ApiUser').find({ email: 'web.admin.ajax@internal.apiumbrella' }, function(error, users) {
        should.not.exist(error);
        users.length.should.eql(1);
        var user = users[0].toObject();
        user._id.should.match(uuidRegex);
        user.api_key.should.match(apiKeyRegex);
        user.email.should.eql('web.admin.ajax@internal.apiumbrella');
        user.registration_source.should.eql('seed');
        user.roles.should.eql(['api-umbrella-key-creator']);
        user.settings._id.should.match(uuidRegex);
        user.settings.rate_limit_mode.should.eql('unlimited');
        should.not.exist(user.settings.rate_limits);
        user.created_at.should.be.a('date');
        user.updated_at.should.be.a('date');
        done();
      });
    });

    it('generates the initial superusers with tokens', function(done) {
      mongoose.testConnection.model('Admin').find({}, function(error, admins) {
        should.not.exist(error);
        admins.length.should.eql(1);
        var admin = admins[0].toObject();
        admin.username.should.eql('initial.admin@example.com');
        admin.superuser.should.eql(true);
        admin._id.should.match(uuidRegex);
        admin.authentication_token.should.match(apiKeyRegex);
        done();
      });
    });

    it('seeds the initial admin permission records', function(done) {
      mongoose.testConnection.model('AdminPermission').find({}, function(error, permissions) {
        permissions.length.should.eql(6);

        var ids = permissions.map(function(p) { return p.toObject()._id; });
        ids.sort().should.eql([
          'analytics',
          'user_view',
          'user_manage',
          'admin_manage',
          'backend_manage',
          'backend_publish',
        ].sort());

        var names = permissions.map(function(p) { return p.toObject().name; });
        names.sort().should.eql([
          'Analytics',
          'API Users - View',
          'API Users - Manage',
          'Admin Accounts - View & Manage',
          'API Backend Configuration - View & Manage',
          'API Backend Configuration - Publish',
        ].sort());

        var permission = permissions[0].toObject();
        permission._id.should.be.a('string');
        permission.name.should.be.a('string');
        permission.display_order.should.be.a('number');
        permission.created_at.should.be.a('date');
        permission.updated_at.should.be.a('date');

        done();
      });
    });
  });
});
