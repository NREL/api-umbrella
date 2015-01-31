'use strict';

require('../test_helper');

var _ = require('lodash'),
    Curler = require('curler').Curler,
    Factory = require('factory-lady'),
    mongoose = require('mongoose'),
    request = require('request');

describe('request rewriting', function() {
  describe('api key stripping', function() {
    shared.runServer();

    it('strips the api key from the header', function(done) {
      var options = {
        headers: {
          'X-Api-Key': this.apiKey,
        }
      };

      request.get('http://localhost:9333/info/', options, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        should.not.exist(data.headers['x-api-key']);

        done();
      }.bind(this));
    });

    it('strips the api key from the query string', function(done) {
      request.get('http://localhost:9333/info/?test=test&api_key=' + this.apiKey, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.url.query.should.eql({ 'test': 'test' });

        done();
      }.bind(this));
    });

    it('strips basic auth if api key was passed in as username', function(done) {
      request.get('http://' + this.apiKey + ':@localhost:9333/info/', function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        should.not.exist(data.headers['authorization']);

        done();
      }.bind(this));
    });

    it('does not strip basic auth if the api key is passed via other means', function(done) {
      request.get('http://foo:@localhost:9333/info/?api_key=' + this.apiKey, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        should.exist(data.headers['authorization']);

        done();
      }.bind(this));
    });

    it('strips the api key from the query string even if the query string contains invalid encoded params', function(done) {
      request.get('http://localhost:9333/info/?test=foo%26%20bar&url=%ED%A1%BC&api_key=' + this.apiKey, function(error, response, body) {
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
      var options = {
        headers: {
          'X-Api-Key': this.apiKey,
        }
      };

      request.get('http://localhost:9333/info/', options, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        should.not.exist(data.headers['x-api-key']);

        done();
      }.bind(this));
    });

    it('strips the api key from the query string', function(done) {
      request.get('http://localhost:9333/info/?test=test&api_key=' + this.apiKey, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.url.query.should.eql({ 'test': 'test' });

        done();
      }.bind(this));
    });

    it('strips basic auth if api key was passed in as username despite not being required', function(done) {
      request.get('http://' + this.apiKey + ':@localhost:9333/info/', function(error, response, body) {
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
      request.get('http://foo:@localhost:9333/info/', function(error, response, body) {
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
      var options = {
        headers: {
          'X-Api-Key': this.apiKey,
        }
      };

      request.get('http://localhost:9333/info/', options, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.headers['x-api-key'].should.eql(this.apiKey);

        done();
      }.bind(this));
    });

    it('passes the api key in the header even if passed in via other means', function(done) {
      request.get('http://localhost:9333/info/?test=test&api_key=' + this.apiKey, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.headers['x-api-key'].should.eql(this.apiKey);

        done();
      }.bind(this));
    });

    it('strips the api key from the query string', function(done) {
      request.get('http://localhost:9333/info/?test=test&api_key=' + this.apiKey, function(error, response, body) {
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
      request.get('http://localhost:9333/info/?api_key=' + this.apiKey, function(error, response, body) {
        var data = JSON.parse(body);
        data.url.query.api_key.should.eql(this.apiKey);

        done();
      }.bind(this));
    });


    it('passes the api key in the query string even if passed in via other means', function(done) {
      var options = {
        headers: {
          'X-Api-Key': this.apiKey,
        }
      };

      request.get('http://localhost:9333/info/', options, function(error, response, body) {
        var data = JSON.parse(body);
        data.url.query.api_key.should.eql(this.apiKey);

        done();
      }.bind(this));
    });
  });

  describe('user id header', function() {
    shared.runServer();

    it('passes a header containing the user id to the backend', function(done) {
      request.get('http://localhost:9333/info/?api_key=' + this.apiKey, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers['x-api-user-id'].should.eql(this.user._id);
        data.headers['x-api-user-id'].length.should.eql(36);

        done();
      }.bind(this));
    });

    it('passes user\'s with object ids as hex strings', function(done) {
      Factory.create('api_user', { _id: mongoose.Types.ObjectId() }, function(user) {
        user._id.should.be.instanceOf(mongoose.Types.ObjectId);

        request.get('http://localhost:9333/info/?api_key=' + user.api_key, function(error, response, body) {
          var data = JSON.parse(body);

          data.headers['x-api-user-id'].should.eql(user._id.toHexString());
          data.headers['x-api-user-id'].length.should.eql(24);

          done();
        });
      });
    });

    it('strips forged role headers on the incoming request', function(done) {
      var options = {
        headers: {
          'X-Api-Key': this.apiKey,
          'X-Api-User-Id': 'bogus',
        }
      };

      request.get('http://localhost:9333/info/', options, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers['x-api-user-id'].should.not.eql('bogus');
        data.headers['x-api-user-id'].length.should.eql(36);

        done();
      });
    });

    it('strips forged role headers, case insensitvely', function(done) {
      var options = {
        headers: {
          'X-Api-Key': this.apiKey,
          'X-API-USER-ID': 'bogus',
        }
      };

      request.get('http://localhost:9333/info/', options, function(error, response, body) {
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
        request.get('http://localhost:9333/info/?api_key=' + user.api_key, function(error, response, body) {
          var data = JSON.parse(body);
          data.headers['x-api-roles'].should.eql('private');

          done();
        });
      });
    });

    it('delimits multiple roles with commas', function(done) {
      Factory.create('api_user', { roles: ['private', 'foo', 'bar'] }, function(user) {
        request.get('http://localhost:9333/info/?api_key=' + user.api_key, function(error, response, body) {
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

        request.get('http://localhost:9333/info/', options, function(error, response, body) {
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

        request.get('http://localhost:9333/info/', options, function(error, response, body) {
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
      request.get('http://localhost:9333/info/?api_key=' + this.apiKey, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers.host.should.eql('example.com');

        done();
      }.bind(this));
    });

    it('includes the port number when given', function(done) {
      request.get('http://localhost:9333/info/port?api_key=' + this.apiKey, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers.host.should.eql('example.com:8080');

        done();
      }.bind(this));
    });

    it('leaves the host header untouched when a backend replacement is not present', function(done) {
      request.get('http://localhost:9333/info/none?api_key=' + this.apiKey, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers.host.should.eql('localhost:9333');

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
      return _.omit(headers, 'host', 'connection', 'x-api-umbrella-backend-scheme', 'x-api-umbrella-backend-id', 'x-api-key', 'x-api-user-id');
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
              frontend_matcher: '/info/:category/:id.:ext?foo=:foo&bar=:bar',
              backend_replacement: '/info/?category={{category}}&id={{id}}&format={{ext}}&foo={{foo}}&bar={{bar}}',
            },
            {
              matcher_type: 'route',
              http_method: 'any',
              frontend_matcher: '/info/wildcard/*after',
              backend_replacement: '/info/after-wildcard/{{after}}',
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
      it('matches a route pattern, without regard to query string ordering', function(done) {
        var options = {
          headers: {
            'X-Api-Key': this.apiKey,
          },
        };

        request.get('http://localhost:9333/info/cat/10.json?bar=hello&foo=goodbye', options, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.query.should.eql({
            'category': 'cat',
            'id': '10',
            'format': 'json',
            'foo': 'goodbye',
            'bar': 'hello',
          });

          done();
        });
      });
    });

    describe('regular expressions', function() {
      it('replaces only the matched part of the regex', function(done) {
        request.get('http://localhost:9333/info/?state=CO&api_key=' + this.apiKey, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.query.should.eql({
            region: 'US-CO',
          });

          done();
        });
      });

      it('replaces all instances of the regex', function(done) {
        request.get('http://localhost:9333/info/state=CO/?state=CO&api_key=' + this.apiKey, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.pathname.should.eql('/info/region=US-CO/');
          data.url.query.should.eql({
            region: 'US-CO',
          });

          done();
        });
      });

      it('matches the regex case insensitively', function(done) {
        request.get('http://localhost:9333/info/?STATE=CO&api_key=' + this.apiKey, function(error, response, body) {
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
        request.get('http://localhost:9333/info/?api_key=' + this.apiKey + '&foo=bar', function(error, response, body) {
          var data = JSON.parse(body);
          data.url.path.should.eql('/info/?foo=moo');

          done();
        });
      });

      it('matches after url prefixes have been replaced', function(done) {
        request.get('http://localhost:9333/info/prefix/?api_key=' + this.apiKey, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.pathname.should.eql('/info/second-replacement/');

          done();
        });
      });

      it('chains multiple replacements in given order', function(done) {
        request.get('http://localhost:9333/info/route/hello?state=CO&api_key=' + this.apiKey, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.path.should.eql('/info/after-route/hello?region=US-CO');

          done();
        });
      });
    });

    it('matches based on the http method', function(done) {
      var url = 'http://localhost:9333/info/?post_only=before&api_key=' + this.apiKey;
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

      request.get('http://localhost:9333/info/?api_key=' + this.apiKey, options, function(error, response, body) {
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

      request.get('http://localhost:9333/info/?api_key=' + this.apiKey, options, function(error, response, body) {
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

      request.get('http://localhost:9333/info/?api_key=' + this.apiKey, options, function(error, response, body) {
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

      request.get('http://localhost:9333/info/?api_key=' + this.apiKey, options, function(error, response, body) {
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

      request.get('http://localhost:9333/info/?api_key=' + this.apiKey, options, function(error, response, body) {
        var data = JSON.parse(body);
        data.headers['cookie'].should.eql('foo=bar; moo=boo');
        done();
      }.bind(this));
    });
  });

  // These tests probably belong in the router project, once we get the full
  // stack more testable there (so we can actually verify Varnish works):
  // https://github.com/NREL/api-umbrella/issues/28
  //
  // Also, this is a little tricky to test in node.js, since all OPTIONS
  // requests originating from node's http library currently add the chunked
  // headers: https://github.com/joyent/node/pull/7725 So we'll drop to a curl
  // library to make these test requests.
  describe('OPTIONS fixes', function() {
    shared.runServer();

    it('does not add chunked headers for requests without a body', function(done) {
      var curl = new Curler();
      curl.request({
        method: 'OPTIONS',
        url: 'http://localhost:9333/info/?test=test&api_key=' + this.apiKey,
      }, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        should.not.exist(data.headers['transfer-encoding']);
        done();
      });
    });

    it('passes chunked headers for requests with a body', function(done) {
      var curl = new Curler();
      curl.request({
        method: 'OPTIONS',
        url: 'http://localhost:9333/info/?test=test&api_key=' + this.apiKey,
        headers: {
          'Transfer-Encoding': 'chunked',
          'Content-Length': '4',
        },
        data: 'test',
      }, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.headers['transfer-encoding'].should.eql('chunked');
        done();
      });
    });
  });
});
