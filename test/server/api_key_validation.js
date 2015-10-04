'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    Factory = require('factory-lady'),
    request = require('request');

describe('api key validation', function() {
  describe('default settings', function() {
    shared.runServer({}, {
      user: { settings: { rate_limit_mode: 'unlimited' } },
    });

    describe('no api key supplied', function() {
      beforeEach(function setupApiUser() {
        this.apiKey = null;
      });

      shared.itBehavesLikeGatekeeperBlocked('/hello', 403, 'API_KEY_MISSING');
    });

    describe('empty api key supplied', function() {
      beforeEach(function setupApiUser() {
        this.apiKey = '';
      });

      shared.itBehavesLikeGatekeeperBlocked('/hello', 403, 'API_KEY_MISSING');
    });

    describe('invalid api key supplied', function() {
      beforeEach(function setupApiUser() {
        this.apiKey = 'invalid';
      });

      shared.itBehavesLikeGatekeeperBlocked('/hello', 403, 'API_KEY_INVALID');
    });

    describe('disabled api key supplied', function() {
      beforeEach(function setupApiUser(done) {
        Factory.create('api_user', { disabled_at: new Date() }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperBlocked('/hello', 403, 'API_KEY_DISABLED');
    });

    describe('valid api key supplied', function() {
      it('calls the target app', function(done) {
        request.get('http://localhost:9080/hello?api_key=' + this.apiKey, function(error, response, body) {
          response.statusCode.should.eql(200);
          body.should.eql('Hello World');
          done();
        });
      });

      it('looks for the api key in the X-Api-Key header', function(done) {
        request.get('http://localhost:9080/hello', { headers: { 'X-Api-Key': this.apiKey } }, function(error, response, body) {
          body.should.eql('Hello World');
          done();
        });
      });

      it('looks for the api key as a GET parameter', function(done) {
        request.get('http://localhost:9080/hello?api_key=' + this.apiKey, function(error, response, body) {
          body.should.eql('Hello World');
          done();
        });
      });

      it('looks for the api key inside the username of basic auth', function(done) {
        request.get('http://' + this.apiKey + ':@localhost:9080/hello', function(error, response, body) {
          body.should.eql('Hello World');
          done();
        });
      });

      it('parses the basic auth scheme case insensitively', function(done) {
        var options = {
          headers: {
            'Authorization': 'basIC ' + new Buffer(this.apiKey + ':').toString('base64'),
          }
        };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          body.should.eql('Hello World');
          done();
        });
      });

      it('parses the basic auth header with extraneous spaces', function(done) {
        var options = {
          headers: {
            'Authorization': '  Basic     ' + new Buffer(this.apiKey + ':').toString('base64') + '   ',
          }
        };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          body.should.eql('Hello World');
          done();
        });
      });

      it('prefers X-Api-Key over all other options', function(done) {
        request.get('http://invalid:@localhost:9080/hello?api_key=invalid', { headers: { 'X-Api-Key': this.apiKey } }, function(error, response, body) {
          body.should.eql('Hello World');
          done();
        });
      });

      it('prefers the GET param over basic auth username', function(done) {
        request.get('http://invalid:@localhost:9080/hello?api_key=' + this.apiKey, function(error, response, body) {
          body.should.eql('Hello World');
          done();
        });
      });

      it('key works across parllel calls (testing key lookup caching behavior)', function(done) {
        async.times(20, function(index, callback) {
          request.get('http://localhost:9080/hello?api_key=' + this.apiKey, function(error, response, body) {
            body.should.eql('Hello World');
            callback();
          });
        }.bind(this), done);
      });

      it('key works across repeated calls (testing key lookup caching behavior)', function(done) {
        async.timesSeries(20, function(index, callback) {
          request.get('http://localhost:9080/hello?api_key=' + this.apiKey, function(error, response, body) {
            body.should.eql('Hello World');
            callback();
          });
        }.bind(this), done);
      });

      it('caches keys locally inside each worker process for a couple seconds', function(done) {
        this.timeout(20000);

        async.series([
          function(next) {
            // Fire off a number of parallel requests so we should hit all the
            // individual worker processes.
            async.timesLimit(100, 10, function(index, timesCallback) {
              request.get('http://localhost:9080/hello?pre&api_key=' + this.apiKey, function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.eql(200);
                body.should.eql('Hello World');
                setTimeout(timesCallback, _.random(5, 100));
              });
            }.bind(this), next);
          }.bind(this),
          function(next) {
            this.user.disabled_at = new Date();
            this.user.save(next);
          }.bind(this),
          function(next) {
            async.timesLimit(100, 10, function(index, timesCallback) {
              request.get('http://localhost:9080/hello?post-save&api_key=' + this.apiKey, function(error, response) {
                setTimeout(function() {
                  timesCallback(error, response.statusCode);
                }, _.random(5, 100));
              });
            }.bind(this), function(error, statusCodes) {
              should.not.exist(error);

              statusCodes.length.should.eql(100);
              var byCode = _.groupBy(statusCodes);
              var successCount = (byCode[200] || []).length;

              // Ensure that at least some of the responses are still successes
              // (due to the cache). Most of the time, all the responses should be
              // successful, but on the off-chance our initial batch of
              // requests didn't hit some of the nginx worker processes, that
              // means the api key won't be cached under that worker process,
              // so it will be returning errors immediately (but that's okay,
              // since all we're really wanting to test is the fact that the
              // cache is present).
              successCount.should.be.gte(1);

              next();
            });
          }.bind(this),
          function(next) {
            setTimeout(next, 2100);
          },
          function(next) {
            async.timesLimit(100, 10, function(index, timesCallback) {
              request.get('http://localhost:9080/hello?post-timeout&api_key=' + this.apiKey, function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.eql(403);
                body.should.include('API_KEY_DISABLED');
                setTimeout(timesCallback, _.random(5, 100));
              });
            }.bind(this), next);
          }.bind(this),
        ], done);
      });
    });

    describe('invalid http basic auth headers', function() {
      it('denies requests with empty authorization header', function(done) {
        var options = {
          headers: {
            'Authorization': '',
          }
        };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          response.statusCode.should.eql(403);
          body.should.include('API_KEY_MISSING');
          done();
        });
      });

      it('denies requests with unknown authorization header', function(done) {
        var options = {
          headers: {
            'Authorization': 'foo bar',
          }
        };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          response.statusCode.should.eql(403);
          body.should.include('API_KEY_MISSING');
          done();
        });
      });

      it('denies requests using the password, rather than username', function(done) {
        var options = {
          headers: {
            'Authorization': 'Basic ' + new Buffer(':' + this.apiKey).toString('base64'),
          }
        };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          response.statusCode.should.eql(403);
          body.should.include('API_KEY_MISSING');
          done();
        });
      });

      it('denies requests with the wrong authorization scheme', function(done) {
        var options = {
          headers: {
            'Authorization': 'Digest ' + new Buffer(this.apiKey + ':').toString('base64'),
          }
        };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          response.statusCode.should.eql(403);
          body.should.include('API_KEY_MISSING');
          done();
        });
      });

      it('denies requests with basic authorization header but value does not include password separator', function(done) {
        var options = {
          headers: {
            'Authorization': 'Basic ' + new Buffer(this.apiKey).toString('base64'),
          }
        };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          response.statusCode.should.eql(403);
          body.should.include('API_KEY_MISSING');
          done();
        });
      });

      it('denies requests with basic authorization header but no value (without space)', function(done) {
        var options = {
          headers: {
            'Authorization': 'Basic',
          }
        };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          response.statusCode.should.eql(403);
          body.should.include('API_KEY_MISSING');
          done();
        });
      });

      it('denies requests with basic authorization header but no value (with space)', function(done) {
        var options = {
          headers: {
            'Authorization': 'Basic ',
          }
        };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          response.statusCode.should.eql(403);
          body.should.include('API_KEY_MISSING');
          done();
        });
      });

      it('denies requests with basic authorization header without valid base64 encoded value (decodes to empty string)', function(done) {
        var options = {
          headers: {
            'Authorization': 'Basic z',
          }
        };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          response.statusCode.should.eql(403);
          body.should.include('API_KEY_MISSING');
          done();
        });
      });

      it('denies requests with basic authorization header without valid base64 encoded value (invalid base64 characters)', function(done) {
        var options = {
          headers: {
            'Authorization': 'Basic zF7&F@#@@',
          }
        };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          response.statusCode.should.eql(403);
          body.should.include('API_KEY_MISSING');
          done();
        });
      });

      it('denies requests with basic authorization header without valid base64 encoded value (decodes to binary)', function(done) {
        var options = {
          headers: {
            'Authorization': 'Basic /9j/4AAQSkZJRgABAQAAAQABAAD//gA',
          }
        };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          response.statusCode.should.eql(403);
          body.should.include('API_KEY_MISSING');
          done();
        });
      });
    });
  });

  describe('custom api key settings', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/info/no-keys',
              backend_prefix: '/info/no-keys',
            }
          ],
          settings: {
            disable_api_key: true,
            rate_limit_mode: 'unlimited',
          },
          sub_settings: [
            {
              http_method: 'any',
              regex: 'force_disabled=true',
              settings: {
                disable_api_key: true,
              },
            },
            {
              http_method: 'any',
              regex: '^/info/no-keys/nevermind',
              settings: {
                disable_api_key: false,
              },
            },
            {
              http_method: 'POST',
              regex: '^/info/no-keys/post-required',
              settings: {
                disable_api_key: false,
              },
            },
            {
              http_method: 'any',
              regex: '^/info/no-keys/inherit',
              settings: {
                disable_api_key: null,
              },
            },
          ],
        },
        {
          'frontend_host': 'localhost',
          'backend_host': 'example.com',
          'url_matches': [
            {
              'frontend_prefix': '/',
              'backend_prefix': '/',
            }
          ],
        },
      ],
    });

    it('defaults to requiring api keys', function(done) {
      request.get('http://localhost:9080/info/', function(error, response) {
        response.statusCode.should.eql(403);
        done();
      });
    });

    it('allows api keys to be disabled for specific url prefixes', function(done) {
      request.get('http://localhost:9080/info/no-keys', function(error, response) {
        response.statusCode.should.eql(200);
        done();
      });
    });

    it('still verifies api keys if given, even if not required', function(done) {
      request.get('http://localhost:9080/info/no-keys?api_key=invalid', function(error, response) {
        response.statusCode.should.eql(403);

        request.get('http://localhost:9080/info/no-keys?api_key=' + this.apiKey, function(error, response) {
          response.statusCode.should.eql(200);
          done();
        });
      }.bind(this));
    });

    describe('sub-url settings', function() {
      it('inherits from the parent api setting when null', function(done) {
        request.get('http://localhost:9080/info/no-keys/inherit', function(error, response) {
          response.statusCode.should.eql(200);
          done();
        });
      });

      it('allows sub-url matches to override the parent api setting', function(done) {
        request.get('http://localhost:9080/info/no-keys/nevermind', function(error, response) {
          response.statusCode.should.eql(403);
          done();
        });
      });

      it('matches the sub-url settings in order', function(done) {
        request.get('http://localhost:9080/info/no-keys/nevermind?force_disabled=true', function(error, response) {
          response.statusCode.should.eql(200);
          done();
        });
      });

      it('matches based on the http method', function(done) {
        var url = 'http://localhost:9080/info/no-keys/post-required';
        request.get(url, function(error, response) {
          response.statusCode.should.eql(200);

          request.post(url, function(error, response) {
            response.statusCode.should.eql(403);
            done();
          });
        });
      });

      it('does not let sub-settings affect subsequent calls to the parent', function(done) {
        request.post('http://localhost:9080/info/no-keys/post-required', function(error, response) {
          response.statusCode.should.eql(403);

          request.get('http://localhost:9080/info/no-keys', function(error, response) {
            response.statusCode.should.eql(200);
            done();
          });
        });
      });
    });
  });

  describe('api key verification levels', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/info/api-key-verification',
              backend_prefix: '/info/api-key-verification',
            }
          ],
          settings: {},
          sub_settings: [
            {
              http_method: 'any',
              regex: '^/info/api-key-verification/none',
              settings: {
                api_key_verification_level: 'none',
              },
            },
            {
              http_method: 'any',
              regex: '^/info/api-key-verification/transition_email',
              settings: {
                api_key_verification_level: 'transition_email',
                api_key_verification_transition_start_at: new Date(2013, 1, 1, 1, 27, 0),
              },
            },
            {
              http_method: 'any',
              regex: '^/info/api-key-verification/required_email',
              settings: {
                api_key_verification_level: 'required_email',
              },
            },
          ],
        },
      ],
    });

    describe('default (none)', function() {
      describe('unknown verification api user', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { email_verified: null }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/api-key-verification/');
      });

      describe('unverified api user', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { email_verified: false }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/api-key-verification/');
      });

      describe('verified api user', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { email_verified: true }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/api-key-verification/');
      });
    });

    describe('none', function() {
      describe('unknown verification api user', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { email_verified: null }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/api-key-verification/none');
      });

      describe('unverified api user', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { email_verified: false }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/api-key-verification/none');
      });

      describe('verified api user', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { email_verified: true }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/api-key-verification/none');
      });
    });

    describe('transition_email', function() {
      describe('unknown verification api user created before the transition start', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { created_at: new Date(2013, 1, 1, 1, 26, 59), email_verified: null }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/api-key-verification/transition_email');
      });

      describe('unverified api user created before the transition start', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { created_at: new Date(2013, 1, 1, 1, 26, 59), email_verified: false }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/api-key-verification/transition_email');
      });

      describe('unknown verification api user created on or after the transition start', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { created_at: new Date(2013, 1, 1, 1, 27, 0), email_verified: null }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperBlocked('/info/api-key-verification/transition_email', 403, 'API_KEY_UNVERIFIED');
      });

      describe('unverified api user created on or after the transition start', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { created_at: new Date(2013, 1, 1, 1, 27, 0), email_verified: false }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperBlocked('/info/api-key-verification/transition_email', 403, 'API_KEY_UNVERIFIED');
      });

      describe('verified api user created before the transition start', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { created_at: new Date(2013, 1, 1, 1, 26, 59), email_verified: true }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/api-key-verification/transition_email');
      });

      describe('verified api user created on or after the transition start', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { created_at: new Date(2013, 1, 1, 1, 27, 0), email_verified: true }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/api-key-verification/transition_email');
      });
    });

    describe('required_email', function() {
      describe('unknown verification api user', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { email_verified: null }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperBlocked('/info/api-key-verification/required_email', 403, 'API_KEY_UNVERIFIED');
      });

      describe('unverified api user', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { email_verified: false }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperBlocked('/info/api-key-verification/required_email', 403, 'API_KEY_UNVERIFIED');
      });

      describe('verified api user', function() {
        beforeEach(function createApiUser(done) {
          Factory.create('api_user', { email_verified: true }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/api-key-verification/required_email');
      });
    });
  });

  describe('api key caching disabled', function() {
    shared.runServer({
      gatekeeper: {
        api_key_cache: false,
      }
    }, {
      user: { settings: { rate_limit_mode: 'unlimited' } },
    });

    it('does not cache keys locally inside each worker process', function(done) {
      async.series([
        function(next) {
          // Fire off a number of parallel requests so we should hit all the
          // individual worker processes.
          async.timesLimit(100, 10, function(index, timesCallback) {
            request.get('http://localhost:9080/hello?pre&api_key=' + this.apiKey, function(error, response, body) {
              should.not.exist(error);
              response.statusCode.should.eql(200);
              body.should.eql('Hello World');
              setTimeout(timesCallback, _.random(0, 5));
            });
          }.bind(this), next);
        }.bind(this),
        function(next) {
          this.user.disabled_at = new Date();
          this.user.save(next);
        }.bind(this),
        function(next) {
          async.timesLimit(100, 10, function(index, timesCallback) {
            request.get('http://localhost:9080/hello?post-save&api_key=' + this.apiKey, function(error, response, body) {
              should.not.exist(error);
              response.statusCode.should.eql(403);
              body.should.include('API_KEY_DISABLED');
              setTimeout(timesCallback, _.random(0, 5));
            });
          }.bind(this), next);
        }.bind(this),
      ], done);
    });
  });
});
