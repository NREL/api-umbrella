'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    Factory = require('factory-lady'),
    request = require('request');

describe('web apis', function() {
  shared.runServer({
    apis: [
      {
        _id: 'will-update',
        frontend_host: 'localhost',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9444,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/info/will-update/',
            backend_prefix: '/info/pre-update/',
          },
        ],
        sort_order: 100,
      },
      {
        _id: 'restricted',
        frontend_host: 'localhost',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9444,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/restricted/',
            backend_prefix: '/info/',
          },
        ],
        settings: {
          required_roles: ['restricted'],
        },
        sort_order: 200,
      },
      {
        _id: 'example',
        frontend_host: 'localhost',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9444,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/',
            backend_prefix: '/',
          },
        ],
        sort_order: 300,
      },
    ],
  });

  before(function createAdmin(done) {
    Factory.create('api_user', { roles: ['api-umbrella-key-creator'] }, function(user) {
      this.keyCreatorApiKey = user.api_key;
      done();
    }.bind(this));
  });

  before(function createAdmin(done) {
    Factory.create('admin', function(admin) {
      this.adminToken = admin.authentication_token;
      done();
    }.bind(this));
  });

  it('allows api keys created with the api to be used immediately', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'X-Api-Key': this.keyCreatorApiKey,
      },
      json: {
        user: {
          first_name: 'John',
          last_name: 'Doe',
          email: 'john@example.com',
          terms_and_conditions: true,
        },
      },
    });

    request.post('http://localhost:9080/api-umbrella/v1/users', options, function(error, response, body) {
      should.not.exist(error);
      response.statusCode.should.eql(201);
      var newUser = body.user;

      request.get('http://localhost:9080/info/?api_key=' + newUser.api_key, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.headers['x-api-user-id'].should.eql(newUser.id);

        done();
      });
    });
  });

  it('detects role changes (within 2 seconds) to api keys modified by the user api', function(done) {
    this.timeout(10000);

    async.series([
      // Wait 2 seconds so we know the initial key created for this test (in
      // the before createDefaultApiUser action) has already been seen by the
      // background task that clears the cache.
      function(next) {
        setTimeout(next, 2100);
      },

      // Ensure that the key words as expected for an initial request.
      function(next) {
        request.get('http://localhost:9080/info/?api_key=' + this.apiKey, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.headers['x-api-user-id'].should.eql(this.user.id);
          should.not.exist(data.headers['x-api-roles']);

          next();
        }.bind(this));
      }.bind(this),

      // Ensure that the key is rejected from a restricted endpoint.
      function(next) {
        request.get('http://localhost:9080/restricted/?api_key=' + this.apiKey, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(403);

          next();
        }.bind(this));
      }.bind(this),

      // Update the key using the API to add the restricted role.
      function(next) {
        var options = _.merge({}, this.options, {
          headers: {
            'X-Admin-Auth-Token': this.adminToken,
          },
          json: {
            user: {
              roles: ['restricted'],
            },
          },
        });

        request.put('http://localhost:9080/api-umbrella/v1/users/' + this.user.id, options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);

          next();
        });
      }.bind(this),

      // Wait 2 seconds to ensure the existing cache for this key get purged.
      function(next) {
        setTimeout(next, 2100);
      },

      // The request to the restricted endpoint should now succeed. If it
      // doesn't, the cache purging may not be working as expected.
      function(next) {
        request.get('http://localhost:9080/restricted/?api_key=' + this.apiKey, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.headers['x-api-user-id'].should.eql(this.user.id);
          data.headers['x-api-roles'].should.eql('restricted');

          next();
        }.bind(this));
      }.bind(this),
    ], done);
  });

  it('detects rate limit changes (within 2 seconds) to api keys modified by the user api', function(done) {
    this.timeout(10000);

    async.series([
      // Wait 2 seconds so we know the initial key created for this test (in
      // the before createDefaultApiUser action) has already been seen by the
      // background task that clears the cache.
      function(next) {
        setTimeout(next, 2100);
      },

      // Ensure that the key words as expected for an initial request.
      function(next) {
        request.get('http://localhost:9080/info/?api_key=' + this.apiKey, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.headers['x-api-user-id'].should.eql(this.user.id);
          response.headers['x-ratelimit-limit'].should.eql('1000');

          next();
        }.bind(this));
      }.bind(this),

      // Update the key using the API to add the restricted role.
      function(next) {
        var options = _.merge({}, this.options, {
          headers: {
            'X-Admin-Auth-Token': this.adminToken,
          },
          json: {
            user: {
              settings: {
                rate_limit_mode: 'custom',
                rate_limits: [
                  {
                    duration: 60 * 60 * 1000, // 1 hour
                    accuracy: 1 * 60 * 1000, // 1 minute
                    limit_by: 'apiKey',
                    limit: 10,
                    distributed: true,
                    response_headers: true,
                  }
                ]
              }
            },
          },
        });

        request.put('http://localhost:9080/api-umbrella/v1/users/' + this.user.id, options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);

          next();
        });
      }.bind(this),

      // Wait 2 seconds to ensure the existing cache for this key get purged.
      function(next) {
        setTimeout(next, 2100);
      },

      // The request to the restricted endpoint should now succeed. If it
      // doesn't, the cache purging may not be working as expected.
      function(next) {
        request.get('http://localhost:9080/info/?api_key=' + this.apiKey, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.headers['x-api-user-id'].should.eql(this.user.id);
          response.headers['x-ratelimit-limit'].should.eql('10');

          next();
        }.bind(this));
      }.bind(this),
    ], done);
  });

  it('detects new apis backends (within 1 second) published with the api', function(done) {
    this.timeout(10000);

    async.series([
      // Ensure that we hit the default routing.
      function(next) {
        request.get('http://localhost:9080/info/new-backend/?api_key=' + this.apiKey, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.url.pathname.should.eql('/info/new-backend/');

          next();
        }.bind(this));
      }.bind(this),

      // Create a new API backend (but don't publish yet).
      function(next) {
        var options = _.merge({}, this.options, {
          headers: {
            'X-Admin-Auth-Token': this.adminToken,
          },
          json: {
            api: {
              name: 'New Backend',
              frontend_host: 'localhost',
              backend_host: 'localhost',
              backend_protocol: 'http',
              balance_algorithm: 'least_conn',
              servers: [
                {
                  host: '127.0.0.1',
                  port: 9444,
                },
              ],
              url_matches: [
                {
                  frontend_prefix: '/info/new-backend/',
                  backend_prefix: '/info/new-backend-rewritten/',
                },
              ],
              sort_order: 1,
            },
          },
        });

        request.post('http://localhost:9080/api-umbrella/v1/apis', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(201);
          this.newApiId = body.api.id;

          next();
        }.bind(this));
      }.bind(this),

      // Wait 1 second to ensure time for any backend changes to get picked up. 
      function(next) {
        setTimeout(next, 1100);
      },

      // Ensure that we still hit the default routing, since we haven't published the new API backend.
      function(next) {
        request.get('http://localhost:9080/info/new-backend/?api_key=' + this.apiKey, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.url.pathname.should.eql('/info/new-backend/');

          next();
        }.bind(this));
      }.bind(this),

      // Publish the API backend changes.
      function(next) {
        var options = _.merge({}, this.options, {
          headers: {
            'X-Admin-Auth-Token': this.adminToken,
          },
          json: {
            config: {
              apis: {},
            },
          },
        });
        options.json.config.apis[this.newApiId] = { publish: 1 };

        request.post('http://localhost:9080/api-umbrella/v1/config/publish', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(201);

          next();
        });
      }.bind(this),

      // Wait 1 second to ensure time for any backend changes to get picked up. 
      function(next) {
        setTimeout(next, 1100);
      },

      // The request to the restricted endpoint should now succeed. If it
      // doesn't, the cache purging may not be working as expected.
      function(next) {
        request.get('http://localhost:9080/info/new-backend/?api_key=' + this.apiKey, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.url.pathname.should.eql('/info/new-backend-rewritten/');

          next();
        }.bind(this));
      }.bind(this),
    ], done);
  });

  it('detects api backend changes (within 1 second) published with the api', function(done) {
    this.timeout(10000);

    async.series([
      // Create a new API backend that we will subsequently publish and then
      // update.
      function(next) {
        var options = _.merge({}, this.options, {
          headers: {
            'X-Admin-Auth-Token': this.adminToken,
          },
          json: {
            api: {
              name: 'Backend to Update',
              frontend_host: 'localhost',
              backend_host: 'localhost',
              backend_protocol: 'http',
              balance_algorithm: 'least_conn',
              servers: [
                {
                  host: '127.0.0.1',
                  port: 9444,
                },
              ],
              url_matches: [
                {
                  frontend_prefix: '/info/will-update/',
                  backend_prefix: '/info/pre-update/',
                },
              ],
              sort_order: 1,
            },
          },
        });

        request.post('http://localhost:9080/api-umbrella/v1/apis', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(201);
          this.newApiId = body.api.id;

          next();
        }.bind(this));
      }.bind(this),

      // Publish the new API backend.
      function(next) {
        var options = _.merge({}, this.options, {
          headers: {
            'X-Admin-Auth-Token': this.adminToken,
          },
          json: {
            config: {
              apis: {},
            },
          },
        });
        options.json.config.apis[this.newApiId] = { publish: 1 };

        request.post('http://localhost:9080/api-umbrella/v1/config/publish', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(201);

          next();
        });
      }.bind(this),

      // Wait 1 second to ensure time for any backend changes to get picked up. 
      function(next) {
        setTimeout(next, 1100);
      },

      // Ensure that we still hit the initial published routing.
      function(next) {
        request.get('http://localhost:9080/info/will-update/?api_key=' + this.apiKey, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.url.pathname.should.eql('/info/pre-update/');

          next();
        }.bind(this));
      }.bind(this),

      // Update the existing API backend.
      function(next) {
        var options = _.merge({}, this.options, {
          headers: {
            'X-Admin-Auth-Token': this.adminToken,
          },
          json: {
            api: {
              servers: [
                {
                  host: '127.0.0.1',
                  port: 9444,
                },
              ],
              url_matches: [
                {
                  frontend_prefix: '/info/will-update/',
                  backend_prefix: '/info/post-update/',
                },
              ],
            },
          },
        });

        request.put('http://localhost:9080/api-umbrella/v1/apis/' + this.newApiId, options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(204);

          next();
        }.bind(this));
      }.bind(this),

      // Publish the API backend updates.
      function(next) {
        var options = _.merge({}, this.options, {
          headers: {
            'X-Admin-Auth-Token': this.adminToken,
          },
          json: {
            config: {
              apis: {},
            },
          },
        });
        options.json.config.apis[this.newApiId] = { publish: 1 };

        request.post('http://localhost:9080/api-umbrella/v1/config/publish', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(201);

          next();
        });
      }.bind(this),

      // Wait 1 second to ensure time for any backend changes to get picked up. 
      function(next) {
        setTimeout(next, 1100);
      },

      // Ensure that the backend is routing the new location.
      function(next) {
        request.get('http://localhost:9080/info/will-update/?api_key=' + this.apiKey, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.url.pathname.should.eql('/info/post-update/');

          next();
        }.bind(this));
      }.bind(this),
    ], done);
  });

  describe('performs "api-umbrella-key-creator" role checks in the web app, not the proxy layer, so that the role logic can be conditional', function() {
    beforeEach(function() {
      this.userOptions = _.merge({}, this.options, {
        json: {
          user: {
            first_name: 'John',
            last_name: 'Doe',
            email: 'john@example.com',
            terms_and_conditions: true,
          },
        },
      });
    });

    it('rejects requests from normal keys without the role', function(done) {
      var options = _.merge({}, this.userOptions, {
        headers: {
          'X-Api-Key': this.apiKey,
        },
      });

      request.post('http://localhost:9080/api-umbrella/v1/users', options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(401);
        done();
      });
    });

    it('allows requests from normal keys with the role', function(done) {
      var options = _.merge({}, this.userOptions, {
        headers: {
          'X-Api-Key': this.keyCreatorApiKey,
        },
      });

      request.post('http://localhost:9080/api-umbrella/v1/users', options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(201);
        done();
      });
    });

    it('rejects requests from admin accounts without an api key', function(done) {
      var options = _.merge({}, this.userOptions, {
        headers: {
          'X-Admin-Auth-Token': this.adminToken,
          'X-Api-Key': null,
        },
      });

      request.post('http://localhost:9080/api-umbrella/v1/users', options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(403);
        done();
      });
    });

    it('allows requests from admin accounts without the role', function(done) {
      var options = _.merge({}, this.userOptions, {
        headers: {
          'X-Admin-Auth-Token': this.adminToken,
          'X-Api-Key': this.apiKey,
        },
      });

      request.post('http://localhost:9080/api-umbrella/v1/users', options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(201);
        done();
      });
    });

    it('allows requests from admin accounts with the role', function(done) {
      var options = _.merge({}, this.userOptions, {
        headers: {
          'X-Admin-Auth-Token': this.adminToken,
          'X-Api-Key': this.apiKey,
        },
      });

      request.post('http://localhost:9080/api-umbrella/v1/users', options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(201);
        done();
      });
    });
  });
});
