'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    Curler = require('curler').Curler,
    Factory = require('factory-lady'),
    mongoose = require('mongoose'),
    request = require('request');

describe('request rewriting', function() {
  function stripStandardHeaders(headers) {
    return _.omit(headers, 'host', 'connection', 'x-api-key', 'x-api-user-id', 'x-api-umbrella-request-id', 'x-forwarded-for', 'x-forwarded-port', 'x-forwarded-proto', 'via');
  }

  describe('api key stripping', function() {
    shared.runServer();

    it('strips the api key from the header', function(done) {
      request.get('http://localhost:9080/info/', this.options, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        should.not.exist(data.headers['x-api-key']);

        done();
      }.bind(this));
    });

    it('strips the api key from the query string', function(done) {
      request.get('http://localhost:9080/info/?test=test&api_key=' + this.apiKey, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.url.query.should.eql({ 'test': 'test' });

        done();
      }.bind(this));
    });

    it('strips basic auth if api key was passed in as username', function(done) {
      request.get('http://' + this.apiKey + ':@localhost:9080/info/', function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        should.not.exist(data.headers['authorization']);

        done();
      }.bind(this));
    });

    it('does not strip basic auth if the api key is passed via other means', function(done) {
      request.get('http://foo:@localhost:9080/info/?api_key=' + this.apiKey, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        should.exist(data.headers['authorization']);

        done();
      }.bind(this));
    });

    it('strips the api key from the query string even if the query string contains invalid encoded params', function(done) {
      request.get('http://localhost:9080/info/?test=foo%26%20bar&url=%ED%A1%BC&api_key=' + this.apiKey, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        Object.keys(data.url.query).sort().should.eql([
          'test',
          'url',
        ]);
        data.url.query.test.should.eql('foo& bar');
        (new Buffer(data.url.query.url)).toString('base64').should.eql('77+9');

        done();
      }.bind(this));
    });
  });

  describe('api key stripping when api keys are not required', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/',
              backend_prefix: '/',
            }
          ],
          settings: {
            disable_api_key: true,
          },
        },
      ],
    });

    it('strips the api key from the header', function(done) {
      request.get('http://localhost:9080/info/', this.options, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        should.not.exist(data.headers['x-api-key']);

        done();
      }.bind(this));
    });

    it('strips the api key from the query string', function(done) {
      request.get('http://localhost:9080/info/?test=test&api_key=' + this.apiKey, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.url.query.should.eql({ 'test': 'test' });

        done();
      }.bind(this));
    });

    it('strips basic auth if api key was passed in as username despite not being required', function(done) {
      request.get('http://' + this.apiKey + ':@localhost:9080/info/', function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        should.not.exist(data.headers['authorization']);

        done();
      }.bind(this));
    });

    // FIXME: This situation of a key being passed along in http basic auth
    // even when not required currently triggers a 403 (since the gatekeeper
    // assumes the username is a key which then isn't valid). I don't think
    // this is the behavior we want, so need to figure out how to address this.
    xit('does not strip basic auth if it contains non-api key auth', function(done) {
      request.get('http://foo:@localhost:9080/info/', function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        console.info(data);
        should.exist(data.headers['authorization']);

        done();
      }.bind(this));
    });
  });

  describe('passing api key via header', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/',
              backend_prefix: '/',
            }
          ],
          settings: {
            pass_api_key_header: true,
          },
        },
      ],
    });

    it('keeps the api key in the header', function(done) {
      request.get('http://localhost:9080/info/', this.options, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.headers['x-api-key'].should.eql(this.apiKey);

        done();
      }.bind(this));
    });

    it('passes the api key in the header even if passed in via other means', function(done) {
      request.get('http://localhost:9080/info/?test=test&api_key=' + this.apiKey, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.headers['x-api-key'].should.eql(this.apiKey);

        done();
      }.bind(this));
    });

    it('strips the api key from the query string', function(done) {
      request.get('http://localhost:9080/info/?test=test&api_key=' + this.apiKey, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.url.query.should.eql({ 'test': 'test' });

        done();
      }.bind(this));
    });
  });

  describe('passing api key via get query param', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/',
              backend_prefix: '/',
            }
          ],
          settings: {
            pass_api_key_query_param: true,
          },
        },
      ],
    });

    it('keeps the api key in the query string', function(done) {
      request.get('http://localhost:9080/info/?api_key=' + this.apiKey, function(error, response, body) {
        var data = JSON.parse(body);
        data.url.query.api_key.should.eql(this.apiKey);

        done();
      }.bind(this));
    });

    it('passes the api key in the query string even if passed in via other means', function(done) {
      request.get('http://localhost:9080/info/', this.options, function(error, response, body) {
        var data = JSON.parse(body);
        data.url.query.api_key.should.eql(this.apiKey);

        done();
      }.bind(this));
    });
  });

  describe('user id header', function() {
    shared.runServer();

    it('passes a header containing the user id to the backend', function(done) {
      request.get('http://localhost:9080/info/?api_key=' + this.apiKey, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers['x-api-user-id'].should.eql(this.user._id);
        data.headers['x-api-user-id'].length.should.eql(36);

        done();
      }.bind(this));
    });

    it('passes user\'s with object ids as hex strings', function(done) {
      Factory.create('api_user', { _id: mongoose.Types.ObjectId() }, function(user) {
        user._id.should.be.instanceOf(mongoose.Types.ObjectId);

        request.get('http://localhost:9080/info/?api_key=' + user.api_key, function(error, response, body) {
          var data = JSON.parse(body);

          data.headers['x-api-user-id'].should.eql(user._id.toHexString());
          data.headers['x-api-user-id'].length.should.eql(24);

          done();
        });
      });
    });

    it('strips forged role headers on the incoming request', function(done) {
      var options = _.merge({}, this.options, {
        headers: {
          'X-Api-User-Id': 'bogus',
        }
      });

      request.get('http://localhost:9080/info/', options, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers['x-api-user-id'].should.not.eql('bogus');
        data.headers['x-api-user-id'].length.should.eql(36);

        done();
      });
    });

    it('strips forged role headers, case insensitvely', function(done) {
      var options = _.merge({}, this.options, {
        headers: {
          'X-API-USER-ID': 'bogus',
        }
      });

      request.get('http://localhost:9080/info/', options, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers['x-api-user-id'].should.not.eql('bogus');
        data.headers['x-api-user-id'].length.should.eql(36);
        should.not.exist(data.headers['X-Api-User-Id']);
        should.not.exist(data.headers['X-API-USER-ID']);

        done();
      });
    });
  });

  describe('roles header', function() {
    shared.runServer();

    it('passes a header defining the user\'s roles to the backend', function(done) {
      Factory.create('api_user', { roles: ['private'] }, function(user) {
        request.get('http://localhost:9080/info/?api_key=' + user.api_key, function(error, response, body) {
          var data = JSON.parse(body);
          data.headers['x-api-roles'].should.eql('private');

          done();
        });
      });
    });

    it('delimits multiple roles with commas', function(done) {
      Factory.create('api_user', { roles: ['private', 'foo', 'bar'] }, function(user) {
        request.get('http://localhost:9080/info/?api_key=' + user.api_key, function(error, response, body) {
          var data = JSON.parse(body);
          data.headers['x-api-roles'].should.eql('private,foo,bar');

          done();
        });
      });
    });

    it('strips forged role headers on the incoming request', function(done) {
      Factory.create('api_user', { roles: null }, function(user) {
        var options = {
          headers: {
            'X-Api-Key': user.api_key,
            'X-Api-Roles': 'bogus',
          }
        };

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          var data = JSON.parse(body);
          should.not.exist(data.headers['x-api-roles']);
          should.not.exist(data.headers['X-Api-Roles']);

          done();
        });
      });
    });

    it('strips forged role headers, case insensitvely', function(done) {
      Factory.create('api_user', { roles: null }, function(user) {
        var options = {
          headers: {
            'X-Api-Key': user.api_key,
            'X-API-ROLES': 'bogus',
          }
        };

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          var data = JSON.parse(body);
          should.not.exist(data.headers['x-api-roles']);
          should.not.exist(data.headers['X-Api-Roles']);
          should.not.exist(data.headers['X-API-ROLES']);

          done();
        });
      });
    });
  });

  describe('host header', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: null,
          url_matches: [
            {
              frontend_prefix: '/info/none',
              backend_prefix: '/info/none',
            }
          ],
        },
        {
          frontend_host: 'localhost',
          backend_host: 'example.com:8080',
          url_matches: [
            {
              frontend_prefix: '/info/port',
              backend_prefix: '/info/port',
            }
          ],
        },
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/',
              backend_prefix: '/',
            }
          ],
        },
      ],
    });

    it('sets the host header', function(done) {
      request.get('http://localhost:9080/info/?api_key=' + this.apiKey, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers.host.should.eql('example.com');

        done();
      }.bind(this));
    });

    it('includes the port number when given', function(done) {
      request.get('http://localhost:9080/info/port?api_key=' + this.apiKey, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers.host.should.eql('example.com:8080');

        done();
      }.bind(this));
    });

    it('leaves the host header untouched when a backend replacement is not present', function(done) {
      request.get('http://localhost:9080/info/none?api_key=' + this.apiKey, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers.host.should.eql('localhost:9080');

        done();
      }.bind(this));
    });
  });

  describe('appending query strings', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
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
        request.get('http://localhost:9080/info/?test=test', this.options, function(error, response, body) {
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
        request.get('http://localhost:9080/info/?test=test&add_param1=original', this.options, function(error, response, body) {
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
        request.get('http://localhost:9080/info/sub/', this.options, function(error, response, body) {
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

    describe('default', function() {
      it('sets header values', function(done) {
        request.get('http://localhost:9080/info/?api_key=' + this.apiKey, function(error, response, body) {
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

        request.get('http://localhost:9080/info/?api_key=' + this.apiKey, options, function(error, response, body) {
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
        request.get('http://localhost:9080/info/sub/?api_key=' + this.apiKey, function(error, response, body) {
          var data = JSON.parse(body);
          stripStandardHeaders(data.headers).should.eql({
            'x-add2': 'overridden',
          });

          done();
        });
      });
    });
  });


  describe('setting dynamic headers', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/',
              backend_prefix: '/',
            }
          ],
          settings: {
            headers: [
              { key: 'X-Dynamic', value: '({{headers.x-dynamic-source}}-{{headers.x-dynamic-source}})' },
              { key: 'X-Dynamic-Missing', value: '{{headers.x-missing}}' },
              { key: 'X-Dynamic-Default-Absent', value: '{{#headers.x-missing}}{{headers.x-missing}}{{/headers.x-missing}}{{^headers.x-missing}}default{{/headers.x-missing}}' },
              { key: 'X-Dynamic-Default-Present', value: '{{#headers.x-dynamic-source}}{{headers.x-dynamic-source}}{{/headers.x-dynamic-source}}{{^headers.x-dynamic-source}}static{{/headers.x-dynamic-source}}' },
            ],
          },
          sub_settings: [
            {
              http_method: 'any',
              regex: '^/info/sub',
              settings: {
                headers: [
                  { key: 'X-Dynamic-Sub', value: '{{headers.x-dynamic-source}}' },
                ],
              },
            },
          ],
        },
      ],
    });

    describe('default', function() {
      it('evaluates dynamic headers including if statements', function(done) {
        var options = {
          headers: {
            'x-dynamic-source': 'dynamic'
          },
        };

        request.get('http://localhost:9080/info/?api_key=' + this.apiKey, options, function(error, response, body) {
          var data = JSON.parse(body);
          stripStandardHeaders(data.headers).should.eql({
            'x-dynamic': '(dynamic-dynamic)',
            'x-dynamic-source': 'dynamic',
            // x-dynamic-missing is not set
            'x-dynamic-default-absent': 'default',
            'x-dynamic-default-present': 'dynamic',
          });

          done();
        });
      });

      it('evaluates dynamic headers including inverted statements', function(done) {
        var options = {
          headers: {
            'x-missing': 'not-missing'
          },
        };

        request.get('http://localhost:9080/info/?api_key=' + this.apiKey, options, function(error, response, body) {
          var data = JSON.parse(body);
          stripStandardHeaders(data.headers).should.eql({
            'x-dynamic': '(-)',
            'x-missing': 'not-missing',
            'x-dynamic-missing': 'not-missing',
            'x-dynamic-default-absent': 'not-missing',
            'x-dynamic-default-present': 'static',
          });

          done();
        });
      });
    });

    describe('sub-url match', function() {
      it('evaluates sub-url dynamic headers', function(done) {
        var options = {
          headers: {
            'x-dynamic-source': 'dynamic'
          },
        };

        request.get('http://localhost:9080/info/sub/?api_key=' + this.apiKey, options, function(error, response, body) {
          var data = JSON.parse(body);
          stripStandardHeaders(data.headers).should.eql({
            'x-dynamic-sub': 'dynamic',
            'x-dynamic-source': 'dynamic'
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
        request.get('http://localhost:9080/auth/?api_key=' + this.apiKey, function(error, response, body) {
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

        request.get('http://localhost:9080/auth/?api_key=' + this.apiKey, options, function(error, response, body) {
          response.statusCode.should.eql(200);
          body.should.eql('somebody');

          done();
        });
      });
    });

    describe('sub-url match', function() {
      it('overrides the default basic auth settings', function(done) {
        request.get('http://localhost:9080/auth/sub/?api_key=' + this.apiKey, function(error, response, body) {
          response.statusCode.should.eql(200);
          body.should.eql('anotheruser');

          done();
        });
      });

      it('passes an unthorized error up if the user/pass in the settings are wrong', function(done) {
        request.get('http://localhost:9080/auth/invalid/?api_key=' + this.apiKey, function(error, response, body) {
          response.statusCode.should.eql(401);
          body.should.eql('Unauthorized');

          done();
        });
      });
    });
  });

  describe('url rewriting', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/info/prefix/',
              backend_prefix: '/info/replacement/',
            },
            {
              frontend_prefix: '/',
              backend_prefix: '/',
            }
          ],
          rewrites: [
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/*wildcard/:category/:id.:ext?foo=:foo&bar=:bar',
              backend_replacement: '/info/?wildcard={{wildcard}}&category={{category}}&id={{id}}&format={{ext}}&foo={{foo}}&bar={{bar}}',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/no-query-string-route',
              backend_replacement: '/info/matched-no-query-string-route',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/named-path/:path_example/:id',
              backend_replacement: '/info/matched-named-path?dir={{path_example}}&id={{id}}',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/named-path-ext.:ext',
              backend_replacement: '/info/matched-named-path-ext?extension={{ext}}',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/named-wildcard-query-string-route?*wildcard',
              backend_replacement: '/info/matched-named-wildcard-query-string-route?{{wildcard}}',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/named-arg?foo=:foo',
              backend_replacement: '/info/matched-named-arg?bar={{foo}}',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/named-args?foo=:foo&bar=:bar',
              backend_replacement: '/info/matched-named-args?bar={{bar}}&foo={{foo}}',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/:path/*wildcard/encoding-test?foo=:foo&bar=:bar&add_path=:add_path',
              backend_replacement: '/info/{{path}}/{{wildcard}}/{{add_path}}/matched-encoding-test?bar={{bar}}&foo={{foo}}&path={{path}}&wildcard={{wildcard}}&add_path={{add_path}}',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/args?foo=1&bar=2',
              backend_replacement: '/info/matched-args',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/*before/wildcard/*after',
              backend_replacement: '/info/{{after}}/matched-wildcard/{{before}}?before={{before}}&after={{after}}',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/with-trailing-slash/?query=foo',
              backend_replacement: '/info/matched-with-trailing-slash-query',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/without-trailing-slash?query=foo',
              backend_replacement: '/info/matched-without-trailing-slash-query',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/with-trailing-slash/',
              backend_replacement: '/info/matched-with-trailing-slash',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/without-trailing-slash',
              backend_replacement: '/info/matched-without-trailing-slash',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/replacement/',
              backend_replacement: '/info/second-replacement/',
            },
            {
              matcher_type: 'regex',
              http_method: 'any',
              frontend_matcher: '^/info/\\?foo=bar$',
              backend_replacement: '/info/?foo=moo',
            },
            {
              matcher_type: 'regex',
              http_method: 'any',
              frontend_matcher: 'state=([A-Z]+)',
              backend_replacement: 'region=US-$1',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/route/*after?region=:region',
              backend_replacement: '/info/after-route/{{after}}?region={{region}}',
            },
            {
              matcher_type: 'regex',
              http_method: 'POST',
              frontend_matcher: 'post_only=before',
              backend_replacement: 'post_only=after',
            },
          ],
        },
      ],
    });

    describe('route patterns', function() {
      it('matches an example with a mixture of path and query string params', function(done) {
        request.get('http://localhost:9080/info/aaa/zzz/cat/10.json?bar=hello&foo=goodbye', this.options, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.query.should.eql({
            'wildcard': 'aaa/zzz',
            'category': 'cat',
            'id': '10',
            'format': 'json',
            'foo': 'goodbye',
            'bar': 'hello',
          });

          done();
        });
      });

      describe('query string argument matching', function() {
        it('matches, but does not pass along the query string when no query string is specified on the route pattern', function(done) {
          request.get('http://localhost:9080/info/no-query-string-route?bar=hello&foo=goodbye', this.options, function(error, response, body) {
            var data = JSON.parse(body);
            data.url.pathname.should.eql('/info/matched-no-query-string-route');
            data.url.query.should.eql({});
            done();
          });
        });

        describe('noncapturing matches', function() {
          it('matches arguments in any order', function(done) {
            request.get('http://localhost:9080/info/args?foo=1&bar=2', this.options, function(error, response, body) {
              var data = JSON.parse(body);
              data.url.path.should.eql('/info/matched-args');

              request.get('http://localhost:9080/info/args?bar=2&foo=1', this.options, function(error, response, body) {
                data = JSON.parse(body);
                data.url.path.should.eql('/info/matched-args');

                done();
              });
            }.bind(this));
          });

          it('does not match if extra arguments are present', function(done) {
            request.get('http://localhost:9080/info/args?foo=1&bar=2&aaa=3', this.options, function(error, response, body) {
              var data = JSON.parse(body);
              data.url.path.should.eql('/info/args?foo=1&bar=2&aaa=3');
              done();
            });
          });

          it('does not match if matched argument is given multiple times', function(done) {
            request.get('http://localhost:9080/info/args?foo=1&bar=2&bar=3', this.options, function(error, response, body) {
              var data = JSON.parse(body);
              data.url.path.should.eql('/info/args?foo=1&bar=2&bar=3');
              done();
            });
          });

          it('does not match if not all the arguments are present', function(done) {
            request.get('http://localhost:9080/info/args?foo=1', this.options, function(error, response, body) {
              var data = JSON.parse(body);
              data.url.path.should.eql('/info/args?foo=1');
              done();
            });
          });
        });

        describe('capturing matches', function() {
          it('matches and replaces named query string arguments', function(done) {
            request.get('http://localhost:9080/info/named-arg?foo=hello', this.options, function(error, response, body) {
              var data = JSON.parse(body);
              data.url.path.should.eql('/info/matched-named-arg?bar=hello');
              done();
            });
          });

          it('comma-delimits the replacement for multiple matches on a named query string argument', function(done) {
            request.get('http://localhost:9080/info/named-arg?foo=hello3&foo=hello1&foo=hello2', this.options, function(error, response, body) {
              var data = JSON.parse(body);

              // JS encodes the commas, Lua does not. Make this test work in
              // both environments while we experiment with Lua.
              if(_.contains(data.url.path, '%2C')) {
                data.url.path.should.eql('/info/matched-named-arg?bar=hello3%2Chello1%2Chello2');
              } else {
                data.url.path.should.eql('/info/matched-named-arg?bar=hello3,hello1,hello2');
              }

              data.url.query.should.eql({
                bar: 'hello3,hello1,hello2',
              });
              done();
            });
          });

          it('matches arguments in any order', function(done) {
            request.get('http://localhost:9080/info/named-args?foo=1&bar=2', this.options, function(error, response, body) {
              var data = JSON.parse(body);
              data.url.path.should.eql('/info/matched-named-args?bar=2&foo=1');

              request.get('http://localhost:9080/info/named-args?bar=2&foo=1', this.options, function(error, response, body) {
                data = JSON.parse(body);
                data.url.path.should.eql('/info/matched-named-args?bar=2&foo=1');

                done();
              });
            }.bind(this));
          });

          it('does not match if extra arguments are present', function(done) {
            request.get('http://localhost:9080/info/named-args?foo=1&bar=2&aaa=3', this.options, function(error, response, body) {
              var data = JSON.parse(body);
              data.url.path.should.eql('/info/named-args?foo=1&bar=2&aaa=3');
              done();
            });
          });

          it('does not match if not all the arguments are present', function(done) {
            request.get('http://localhost:9080/info/named-args?foo=1', this.options, function(error, response, body) {
              var data = JSON.parse(body);
              data.url.path.should.eql('/info/named-args?foo=1');
              done();
            });
          });

          it('maintains url encoding', function(done) {
            request.get('http://localhost:9080/info/a/b/c/d/encoding-test?foo=hello+space+test&bar=1%262*3%254%2F5&add_path=x%2Fy%2Fz', this.options, function(error, response, body) {
              var data = JSON.parse(body);
              data.url.path.should.eql('/info/a/b/c/d/x/y/z/matched-encoding-test?bar=1%262*3%254%2F5&foo=hello%20space%20test&path=a&wildcard=b%2Fc%2Fd&add_path=x%2Fy%2Fz');
              data.url.query.should.eql({
                foo: 'hello space test',
                bar: '1&2*3%4/5',
                path: 'a',
                wildcard: 'b/c/d',
                add_path: 'x/y/z',
              });
              done();
            });
          });

          // Maybe this is something we should support, though?
          it('does not support named wildcards in the query string', function(done) {
            request.get('http://localhost:9080/info/named-wildcard-query-string-route?bar=hello&foo=goodbye', this.options, function(error, response, body) {
              var data = JSON.parse(body);
              data.url.path.should.eql('/info/named-wildcard-query-string-route?bar=hello&foo=goodbye');
              done();
            });
          });
        });
      });

      describe('path matching', function() {
        it('captures named path parameters', function(done) {
          request.get('http://localhost:9080/info/named-path/foo/10', this.options, function(error, response, body) {
            var data = JSON.parse(body);
            data.url.path.should.eql('/info/matched-named-path?dir=foo&id=10');
            done();
          });
        });

        it('does not match multiple levels of path heirarchy with named path parameters', function(done) {
          request.get('http://localhost:9080/info/named-path/foo/bar/10', this.options, function(error, response, body) {
            var data = JSON.parse(body);
            data.url.path.should.eql('/info/named-path/foo/bar/10');
            done();
          });
        });

        it('captures file extensions as named path parameters', function(done) {
          request.get('http://localhost:9080/info/named-path-ext.json', this.options, function(error, response, body) {
            var data = JSON.parse(body);
            data.url.path.should.eql('/info/matched-named-path-ext?extension=json');
            done();
          });
        });

        it('captures multiple wildcards in a single route', function(done) {
          request.get('http://localhost:9080/info/a/b/c/wildcard/d/e/', this.options, function(error, response, body) {
            var data = JSON.parse(body);
            data.url.path.should.eql('/info/d/e/matched-wildcard/a/b/c?before=a%2Fb%2Fc&after=d%2Fe');
            done();
          });
        });

        it('ignores trailing slashes for route matching purposes', function(done) {
          async.parallel([
            function(callback) {
              request.get('http://localhost:9080/info/with-trailing-slash/', this.options, function(error, response, body) {
                var data = JSON.parse(body);
                data.url.pathname.should.eql('/info/matched-with-trailing-slash');
                callback();
              });
            }.bind(this),
            function(callback) {
              request.get('http://localhost:9080/info/with-trailing-slash', this.options, function(error, response, body) {
                var data = JSON.parse(body);
                data.url.pathname.should.eql('/info/matched-with-trailing-slash');
                callback();
              });
            }.bind(this),
            function(callback) {
              request.get('http://localhost:9080/info/without-trailing-slash/', this.options, function(error, response, body) {
                var data = JSON.parse(body);
                data.url.pathname.should.eql('/info/matched-without-trailing-slash');
                callback();
              });
            }.bind(this),
            function(callback) {
              request.get('http://localhost:9080/info/without-trailing-slash', this.options, function(error, response, body) {
                var data = JSON.parse(body);
                data.url.pathname.should.eql('/info/matched-without-trailing-slash');
                callback();
              });
            }.bind(this),
            function(callback) {
              request.get('http://localhost:9080/info/with-trailing-slash/?query=foo', this.options, function(error, response, body) {
                var data = JSON.parse(body);
                data.url.pathname.should.eql('/info/matched-with-trailing-slash-query');
                callback();
              });
            }.bind(this),
            function(callback) {
              request.get('http://localhost:9080/info/with-trailing-slash?query=foo', this.options, function(error, response, body) {
                var data = JSON.parse(body);
                data.url.pathname.should.eql('/info/matched-with-trailing-slash-query');
                callback();
              });
            }.bind(this),
            function(callback) {
              request.get('http://localhost:9080/info/without-trailing-slash/?query=foo', this.options, function(error, response, body) {
                var data = JSON.parse(body);
                data.url.pathname.should.eql('/info/matched-without-trailing-slash-query');
                callback();
              });
            }.bind(this),
            function(callback) {
              request.get('http://localhost:9080/info/without-trailing-slash?query=foo', this.options, function(error, response, body) {
                var data = JSON.parse(body);
                data.url.pathname.should.eql('/info/matched-without-trailing-slash-query');
                callback();
              });
            }.bind(this),
          ], done);
        });
      });
    });

    describe('regular expressions', function() {
      it('replaces only the matched part of the regex', function(done) {
        request.get('http://localhost:9080/info/?state=CO&api_key=' + this.apiKey, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.query.should.eql({
            region: 'US-CO',
          });

          done();
        });
      });

      it('replaces all instances of the regex', function(done) {
        request.get('http://localhost:9080/info/state=CO/?state=CO&api_key=' + this.apiKey, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.pathname.should.eql('/info/region=US-CO/');
          data.url.query.should.eql({
            region: 'US-CO',
          });

          done();
        });
      });

      it('matches the regex case insensitively', function(done) {
        request.get('http://localhost:9080/info/?STATE=CO&api_key=' + this.apiKey, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.query.should.eql({
            region: 'US-CO',
          });

          done();
        });
      });
    });

    describe('ordering', function() {
      it('matches after the api key has been removed from the query string', function(done) {
        request.get('http://localhost:9080/info/?api_key=' + this.apiKey + '&foo=bar', function(error, response, body) {
          var data = JSON.parse(body);
          data.url.path.should.eql('/info/?foo=moo');

          done();
        });
      });

      it('matches after url prefixes have been replaced', function(done) {
        request.get('http://localhost:9080/info/prefix/?api_key=' + this.apiKey, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.pathname.should.eql('/info/second-replacement/');

          done();
        });
      });

      it('chains multiple replacements in given order', function(done) {
        request.get('http://localhost:9080/info/route/hello?state=CO&api_key=' + this.apiKey, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.path.should.eql('/info/after-route/hello?region=US-CO');

          done();
        });
      });
    });

    it('matches based on the http method', function(done) {
      var url = 'http://localhost:9080/info/?post_only=before&api_key=' + this.apiKey;
      request.get(url, function(error, response, body) {
        var data = JSON.parse(body);
        data.url.query.post_only.should.eql('before');

        request.post(url, function(error, response, body) {
          data = JSON.parse(body);
          data.url.query.post_only.should.eql('after');

          done();
        });
      });
    });
  });

  describe('cookie stripping', function() {
    shared.runServer();

    it('removes the cookie completely when only a single analytics cookie is present', function(done) {
      var options = {
        headers: {
          'Cookie': '__utma=foo'
        }
      };

      request.get('http://localhost:9080/info/?api_key=' + this.apiKey, options, function(error, response, body) {
        var data = JSON.parse(body);
        should.not.exist(data.headers['cookie']);
        done();
      }.bind(this));
    });

    it('removes the cookie completely when only multiple analytics cookies are present', function(done) {
      var options = {
        headers: {
          'Cookie': '__utma=foo; __utmz=bar; _ga=foo'
        }
      };

      request.get('http://localhost:9080/info/?api_key=' + this.apiKey, options, function(error, response, body) {
        var data = JSON.parse(body);
        should.not.exist(data.headers['cookie']);
        done();
      }.bind(this));
    });

    it('removes only the analytics cookies when other cookies are present', function(done) {
      var options = {
        headers: {
          'Cookie': '__utma=foo; moo=boo; __utmz=bar; foo=bar; _ga=foo'
        }
      };

      request.get('http://localhost:9080/info/?api_key=' + this.apiKey, options, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers['cookie'].should.eql('moo=boo; foo=bar');
        done();
      }.bind(this));
    });

    it('parses cookies with variable whitespace between entries', function(done) {
      var options = {
        headers: {
          'Cookie': '__utma=foo;moo=boo;    __utmz=bar;    foo=bar;_ga=foo'
        }
      };

      request.get('http://localhost:9080/info/?api_key=' + this.apiKey, options, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers['cookie'].should.eql('moo=boo; foo=bar');
        done();
      }.bind(this));
    });

    it('leaves the cookie alone when no analytics cookies are present', function(done) {
      var options = {
        headers: {
          'Cookie': 'foo=bar; moo=boo'
        }
      };

      request.get('http://localhost:9080/info/?api_key=' + this.apiKey, options, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers['cookie'].should.eql('foo=bar; moo=boo');
        done();
      }.bind(this));
    });
  });

  describe('url encoding', function() {
    shared.runServer();

    // Test for backslashes flipping to forward slashes:
    // https://github.com/joyent/node/pull/8459
    it('passes backslashes', function(done) {
      // Use curl and not request for these tests, since the request library
      // calls url.parse which has a bug that causes backslashes to become
      // forward slashes https://github.com/joyent/node/pull/8459
      var curl = new Curler();
      curl.request({
        method: 'GET',
        url: 'http://localhost:9080/info/test\\backslash?test=\\hello&api_key=' + this.apiKey,
      }, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.url.query.test.should.eql('\\hello');
        data.raw_url.should.eql('http://localhost/info/test\\backslash?test=%5Chello');
        done();
      }.bind(this));
    });
  });
});
