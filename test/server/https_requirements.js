'use strict';

require('../test_helper');

var _ = require('lodash'),
    Factory = require('factory-lady'),
    request = require('request');

describe('https requirements', function() {
  shared.runServer({
    apiSettings: {
      require_https: 'required_return_error',
    },
    apis: [
      {
        frontend_host: 'localhost',
        backend_host: 'example.com',
        url_matches: [
          {
            frontend_prefix: '/info/default/',
            backend_prefix: '/info/',
          }
        ],
        settings: {
          require_https: null,
        },
      },
      {
        frontend_host: 'localhost',
        backend_host: 'example.com',
        url_matches: [
          {
            frontend_prefix: '/info/required_return_error/',
            backend_prefix: '/info/',
          }
        ],
        settings: {
          require_https: 'required_return_error',
        },
      },
      {
        frontend_host: 'localhost',
        backend_host: 'example.com',
        url_matches: [
          {
            frontend_prefix: '/info/transition_return_error/',
            backend_prefix: '/info/',
          }
        ],
        settings: {
          require_https: 'transition_return_error',
          require_https_transition_start_at: new Date(2013, 1, 1, 1, 27, 0),
        },
      },
      {
        frontend_host: 'localhost',
        backend_host: 'example.com',
        url_matches: [
          {
            frontend_prefix: '/info/optional/',
            backend_prefix: '/info/',
          }
        ],
        settings: {
          require_https: 'optional',
        },
        sub_settings: [
          {
            http_method: 'any',
            regex: '^/info/sub-inherit/',
            settings: {
              require_https: null,
            },
          },
          {
            http_method: 'any',
            regex: '^/info/sub-required/',
            settings: {
              require_https: 'required_return_error',
            },
          },
        ],
      },
    ],
  });

  function itBehavesLikeHttpsAllowed(path) {
    describe('https request is allowed', function() {
      shared.itBehavesLikeGatekeeperAllowed(path, {
        followRedirect: false,
        headers: {
          'X-Forwarded-Proto': 'https',
        },
      });
    });
  }

  function itBehavesLikeHttpAllowed(path) {
    describe('http request is allowed', function() {
      shared.itBehavesLikeGatekeeperAllowed(path, {
        followRedirect: false,
        headers: {
          'X-Forwarded-Proto': 'http',
        },
      });
    });
  }

  function itBehavesLikeHttpError(path) {
    describe('http request returns an error', function() {
      shared.itBehavesLikeGatekeeperBlocked(path, 400, 'HTTPS_REQUIRED', {
        followRedirect: false,
        headers: {
          'X-Forwarded-Proto': 'http',
        },
      });

      it('returns the https URL in the error message', function(done) {
        var options = _.merge({}, this.options, {
          followRedirect: false,
          headers: {
            'X-Forwarded-Proto': 'http',
          },
        });

        request('http://localhost:9080' + path + '?foo=bar&hello=world', options, function(error, response, body) {
          should.not.exist(error);
          body.should.include('https://localhost:9081' + path + '?foo=bar&hello=world');
          done();
        });
      });
    });
  }

  describe('required_return_error', function() {
    itBehavesLikeHttpsAllowed('/info/required_return_error/');
    itBehavesLikeHttpError('/info/required_return_error/');
  });

  describe('transition_return_error', function() {
    itBehavesLikeHttpsAllowed('/info/transition_return_error/');

    describe('api user created before the transition start', function() {
      beforeEach(function createApiUser(done) {
        Factory.create('api_user', { created_at: new Date(2013, 1, 1, 1, 26, 59) }, function(user) {
          this.user = user;
          this.apiKey = user.api_key;
          this.options = {
            headers: {
              'X-Api-Key': this.apiKey,
            }
          };
          done();
        }.bind(this));
      });

      itBehavesLikeHttpAllowed('/info/transition_return_error/');
    });

    describe('api user created on or after the transition start', function() {
      beforeEach(function createApiUser(done) {
        Factory.create('api_user', { created_at: new Date(2013, 1, 1, 1, 27, 0) }, function(user) {
          this.user = user;
          this.apiKey = user.api_key;
          this.options = {
            headers: {
              'X-Api-Key': this.apiKey,
            }
          };
          done();
        }.bind(this));
      });

      itBehavesLikeHttpError('/info/transition_return_error/');
    });
  });

  describe('optional', function() {
    itBehavesLikeHttpsAllowed('/info/optional/');
    itBehavesLikeHttpAllowed('/info/optional/');
  });

  describe('inherit/undefined defaults to required_return_error mode', function() {
    itBehavesLikeHttpsAllowed('/info/default/');
    itBehavesLikeHttpError('/info/default/');
  });

  describe('sub-url settings', function() {
    describe('inherit/undefined defaults to the parent mode', function() {
      itBehavesLikeHttpsAllowed('/info/optional/sub-inherit/');
      itBehavesLikeHttpAllowed('/info/optional/sub-inherit/');
    });

    describe('sub setting overrides the mode of the parent', function() {
      itBehavesLikeHttpsAllowed('/info/optional/sub-required/');
      itBehavesLikeHttpError('/info/optional/sub-required/');
    });
  });
});
