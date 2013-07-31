'use strict';

require('../test_helper');

describe('ApiUmbrellaGatekeper', function() {
  shared.runServer({
    proxy: {
      restricted_apis: [
        {
          path_regex: '^/restricted',
          role: 'restricted',
        },
      ],
    }
  });
/*
  beforeEach(function(done) {
    backendCalled = false;
    this.server = gatekeeper.createServer({
      port: 9333,
      backend: 'localhost:9444',
      mongo: 'mongodb://127.0.0.1:27017/api_umbrella_test',
    }, function() {
      done();
    });
  });

  afterEach(function(done) {
    this.server.close(function() {
      done();
    });
  });
  */

  describe('role validation', function() {
    describe('unauthorized api_key with null roles', function() {
      beforeEach(function(done) {
        Factory.create('api_user', { roles: null }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperBlocked('/restricted', 403, 'The api_key supplied is not authorized');
    });

    describe('unauthorized api_key with empty roles', function() {
      beforeEach(function(done) {
        Factory.create('api_user', { roles: null }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperBlocked('/restricted', 403, 'The api_key supplied is not authorized');
    });

    describe('unauthorized api_key with other roles', function() {
      beforeEach(function(done) {
        Factory.create('api_user', { roles: ['something', 'else'] }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperBlocked('/restricted', 403, 'The api_key supplied is not authorized');
    });

    describe('authorized api_key with the appropriate role', function() {
      beforeEach(function(done) {
        Factory.create('api_user', { roles: ['restricted'] }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperAllowed('/restricted');
    });

    describe('non-matching patch', function() {
      beforeEach(function(done) {
        Factory.create('api_user', { roles: null }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperAllowed('/not/restricted');
    });
  });
});
