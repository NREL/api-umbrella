'use strict';

require('../test_helper');

var _ = require('underscore');

describe('request rewriting', function() {
  describe('api key normaliztion', function() {
    shared.runServer();

    it('passes the api key in the header to the backend even if passed in via other means', function(done) {
      request.get('http://localhost:9333/info/?api_key=' + this.apiKey, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers['x-api-key'].should.eql(this.apiKey);

        done();
      }.bind(this));
    });

    it('strips the api key from the query string if given', function(done) {
      request.get('http://localhost:9333/info/?test=test&api_key=' + this.apiKey, function(error, response, body) {
        var data = JSON.parse(body);
        data.url.query.should.eql({ 'test': 'test' });

        done();
      });
    });
  });

  describe('appending query strings', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          id: 'default',
          url_matches: [
            {
              frontend_prefix: '/',
              backend_prefix: '/',
            }
          ],
          settings: {
            append_query_string: 'add_param1=test1&add_param2=test2',
          },
          sub_settings: [
            {
              http_method: 'any',
              regex: '^/info/sub',
              settings: {
                append_query_string: 'add_param2=overridden&add_param3=new',
              },
            },
          ],
        },
      ],
    });

    describe('default', function() {
      it('appends the query string', function(done) {
        var options = {
          headers: {
            'X-Api-Key': this.apiKey,
          },
        };

        request.get('http://localhost:9333/info/?test=test', options, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.query.should.eql({
            'test': 'test',
            'add_param1': 'test1',
            'add_param2': 'test2',
          });

          done();
        });
      });

      it('overrides existing query parameters', function(done) {
        var options = {
          headers: {
            'X-Api-Key': this.apiKey,
          },
        };

        request.get('http://localhost:9333/info/?test=test&add_param1=original', options, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.query.should.eql({
            'test': 'test',
            'add_param1': 'test1',
            'add_param2': 'test2',
          });

          done();
        });
      });
    });

    describe('sub-url match', function() {
      it('overrides the default query string settings', function(done) {
        var options = {
          headers: {
            'X-Api-Key': this.apiKey,
          },
        };

        request.get('http://localhost:9333/info/sub/', options, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.query.should.eql({
            'add_param2': 'overridden',
            'add_param3': 'new',
          });

          done();
        });
      });
    });
  });

  describe('setting headers', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          id: 'default',
          url_matches: [
            {
              frontend_prefix: '/',
              backend_prefix: '/',
            }
          ],
          settings: {
            headers: [
              { key: 'X-Add1', value: 'test1' },
              { key: 'X-Add2', value: 'test2' },
            ],
          },
          sub_settings: [
            {
              http_method: 'any',
              regex: '^/info/sub',
              settings: {
                headers: [
                  { key: 'X-Add2', value: 'overridden' },
                ],
              },
            },
          ],
        },
      ],
    });

    function stripStandardHeaders(headers) {
      return _.omit(headers, 'host', 'connection', 'x-api-umbrella-backend-scheme', 'x-api-umbrella-backend-id', 'x-api-key');
    }

    describe('default', function() {
      it('sets header values', function(done) {
        request.get('http://localhost:9333/info/?api_key=' + this.apiKey, function(error, response, body) {
          var data = JSON.parse(body);
          stripStandardHeaders(data.headers).should.eql({
            'x-add1': 'test1',
            'x-add2': 'test2',
          });

          done();
        });
      });

      it('overrides existing headers (case insensitive)', function(done) {
        var options = {
          headers: {
            'X-ADD1': 'original',
          },
        };

        request.get('http://localhost:9333/info/?api_key=' + this.apiKey, options, function(error, response, body) {
          var data = JSON.parse(body);
          stripStandardHeaders(data.headers).should.eql({
            'x-add1': 'test1',
            'x-add2': 'test2',
          });

          done();
        });
      });
    });

    describe('sub-url match', function() {
      it('overrides the default header settings', function(done) {
        request.get('http://localhost:9333/info/sub/?api_key=' + this.apiKey, function(error, response, body) {
          var data = JSON.parse(body);
          stripStandardHeaders(data.headers).should.eql({
            'x-add2': 'overridden',
          });

          done();
        });
      });
    });
  });

  describe('http basic auth', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          id: 'default',
          url_matches: [
            {
              frontend_prefix: '/auth/',
              backend_prefix: '/auth/',
            }
          ],
          settings: {
            http_basic_auth: 'somebody:secret',
          },
          sub_settings: [
            {
              http_method: 'any',
              regex: '^/auth/sub',
              settings: {
                http_basic_auth: 'anotheruser:anothersecret',
              },
            },
            {
              http_method: 'any',
              regex: '^/auth/invalid',
              settings: {
                http_basic_auth: 'anotheruser:invalid',
              },
            },
          ],
        },
      ],
    });

    describe('default', function() {
      it('sets the http basic authentication', function(done) {
        request.get('http://localhost:9333/auth/?api_key=' + this.apiKey, function(error, response, body) {
          response.statusCode.should.eql(200);
          body.should.eql('somebody');

          done();
        });
      });

      it('overrides existing http basic auth', function(done) {
        var options = {
          auth: {
            user: 'testuser',
            pass: 'testpass',
          },
        };

        request.get('http://localhost:9333/auth/?api_key=' + this.apiKey, options, function(error, response, body) {
          response.statusCode.should.eql(200);
          body.should.eql('somebody');

          done();
        });
      });
    });

    describe('sub-url match', function() {
      it('overrides the default basic auth settings', function(done) {
        request.get('http://localhost:9333/auth/sub/?api_key=' + this.apiKey, function(error, response, body) {
          response.statusCode.should.eql(200);
          body.should.eql('anotheruser');

          done();
        });
      });

      it('passes an unthorized error up if the user/pass in the settings are wrong', function(done) {
        request.get('http://localhost:9333/auth/invalid/?api_key=' + this.apiKey, function(error, response, body) {
          response.statusCode.should.eql(401);
          body.should.eql('Unauthorized');

          done();
        });
      });
    });
  });
});
