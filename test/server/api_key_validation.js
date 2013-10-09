'use strict';

require('../test_helper');

describe('api key validation', function() {
  describe('default settings', function() {
    shared.runServer();

    describe('no api key supplied', function() {
      beforeEach(function() {
        this.apiKey = null;
      });

      shared.itBehavesLikeGatekeeperBlocked('/hello', 403, 'API_KEY_MISSING');
    });

    describe('empty api key supplied', function() {
      beforeEach(function() {
        this.apiKey = '';
      });

      shared.itBehavesLikeGatekeeperBlocked('/hello', 403, 'API_KEY_MISSING');
    });

    describe('invalid api key supplied', function() {
      beforeEach(function() {
        this.apiKey = 'invalid';
      });

      shared.itBehavesLikeGatekeeperBlocked('/hello', 403, 'API_KEY_INVALID');
    });

    describe('disabled api key supplied', function() {
      beforeEach(function(done) {
        Factory.create('api_user', { disabled_at: new Date() }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperBlocked('/hello', 403, 'API_KEY_DISABLED');
    });

    describe('valid api key supplied', function() {
      it('calls the target app', function(done) {
        request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
          backendCalled.should.eql(true);
          response.statusCode.should.eql(200);
          body.should.eql('Hello World');
          done();
        });
      });

      it('looks for the api key in the X-Api-Key header', function(done) {
        request.get('http://localhost:9333/hello', { headers: { 'X-Api-Key': this.apiKey } }, function(error, response, body) {
          body.should.eql('Hello World');
          done();
        });
      });

      it('looks for the api key as a GET parameter', function(done) {
        request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
          body.should.eql('Hello World');
          done();
        });
      });

      it('looks for the api key inside the username of basic auth', function(done) {
        request.get('http://' + this.apiKey + ':@localhost:9333/hello', function(error, response, body) {
          body.should.eql('Hello World');
          done();
        });
      });

      it('prefers X-Api-Key over all other options', function(done) {
        request.get('http://invalid:@localhost:9333/hello?api_key=invalid', { headers: { 'X-Api-Key': this.apiKey } }, function(error, response, body) {
          body.should.eql('Hello World');
          done();
        });
      });

      it('prefers the GET param over basic auth username', function(done) {
        request.get('http://invalid:@localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
          body.should.eql('Hello World');
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
          _id: 'default',
          url_matches: [
            {
              frontend_prefix: '/info/no-keys',
              backend_prefix: '/info/no-keys',
            }
          ],
          settings: {
            disable_api_key: true,
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
          '_id': 'default',
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
      request.get('http://localhost:9333/info/', function(error, response) {
        response.statusCode.should.eql(403);
        done();
      });
    });

    it('allows api keys to be disabled for specific url prefixes', function(done) {
      request.get('http://localhost:9333/info/no-keys', function(error, response) {
        response.statusCode.should.eql(200);
        done();
      });
    });

    it('still verifies api keys if given, even if not required', function(done) {
      request.get('http://localhost:9333/info/no-keys?api_key=invalid', function(error, response) {
        response.statusCode.should.eql(403);

        request.get('http://localhost:9333/info/no-keys?api_key=' + this.apiKey, function(error, response) {
          response.statusCode.should.eql(200);
          done();
        });
      }.bind(this));
    });

    describe('sub-url settings', function() {
      it('inherits from the parent api setting when null', function(done) {
        request.get('http://localhost:9333/info/no-keys/inherit', function(error, response) {
          response.statusCode.should.eql(200);
          done();
        });
      });

      it('allows sub-url matches to override the parent api setting', function(done) {
        request.get('http://localhost:9333/info/no-keys/nevermind', function(error, response) {
          response.statusCode.should.eql(403);
          done();
        });
      });

      it('matches the sub-url settings in order', function(done) {
        request.get('http://localhost:9333/info/no-keys/nevermind?force_disabled=true', function(error, response) {
          response.statusCode.should.eql(200);
          done();
        });
      });

      it('matches based on the http method', function(done) {
        var url = 'http://localhost:9333/info/no-keys/post-required';
        request.get(url, function(error, response) {
          response.statusCode.should.eql(200);

          request.post(url, function(error, response) {
            response.statusCode.should.eql(403);
            done();
          });
        });
      });

      it('does not let sub-settings affect subsequent calls to the parent', function(done) {
        request.post('http://localhost:9333/info/no-keys/post-required', function(error, response) {
          response.statusCode.should.eql(403);

          request.get('http://localhost:9333/info/no-keys', function(error, response) {
            response.statusCode.should.eql(200);
            done();
          });
        });
      });
    });
  });
});
