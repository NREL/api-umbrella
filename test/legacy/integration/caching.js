'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    Factory = require('factory-lady'),
    request = require('request');

describe('caching', function() {
  shared.runServer({
    apis: [
      {
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
            frontend_prefix: '/add-auth-header/',
            backend_prefix: '/',
          },
        ],
        settings: {
          http_basic_auth: 'somebody:secret',
        },
      },
      {
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
            frontend_prefix: '/cacheable-backend-port/prefix/foo/',
            backend_prefix: '/cacheable-backend-port/',
          },
        ],
      },
      {
        frontend_host: 'localhost',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9441,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/cacheable-backend-port/prefix/bar/',
            backend_prefix: '/cacheable-backend-port/',
          },
        ],
      },
      {
        frontend_host: 'localhost',
        backend_host: 'foo.example',
        servers: [
          {
            host: '127.0.0.1',
            port: 9444,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/cacheable-backend-host/prefix/foo/',
            backend_prefix: '/cacheable-backend-host/',
          },
        ],
      },
      {
        frontend_host: 'localhost',
        backend_host: 'bar.example',
        servers: [
          {
            host: '127.0.0.1',
            port: 9444,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/cacheable-backend-host/prefix/bar/',
            backend_prefix: '/cacheable-backend-host/',
          },
        ],
      },
      {
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
      },
    ],
  });

  beforeEach(function createUser(done) {
    Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
      this.apiKey = user.api_key;
      this.options = {
        headers: {
          'X-Api-Key': this.apiKey,
        },
        agentOptions: {
          maxSockets: 500,
        },
      };

      done();
    }.bind(this));
  });

  function makeDuplicateRequests(baseUrl, options, done) {
    var id = _.uniqueId();
    options = _.merge({
      method: 'GET',
    }, options);

    var secondCallOverrides = options.secondCallOverrides || {};
    delete options.secondCallOverrides;

    var secondCallSleep = options.secondCallSleep || 0;
    delete options.secondCallSleep;

    request(baseUrl + id, options, function(error, firstResponse, firstBody) {
      firstResponse.statusCode.should.eql(200);

      setTimeout(function() {
        var secondCallOptions = _.merge({}, options, secondCallOverrides);
        request(baseUrl + id, secondCallOptions, function(error, secondResponse, secondBody) {
          secondResponse.statusCode.should.eql(200);

          done(null, {
            firstResponse: firstResponse,
            firstBody: firstBody,
            secondResponse: secondResponse,
            secondBody: secondBody,
          });
        });
      }, secondCallSleep);
    });
  }

  function actsLikeNotCacheable(baseUrl, options, done) {
    makeDuplicateRequests(baseUrl, options, function(error, result) {
      if(!options.skipBodyCompare) {
        result.firstBody.length.should.be.greaterThan(0);
        result.firstBody.should.not.eql(result.secondBody);
      }

      result.firstResponse.headers['x-unique-output'].length.should.be.greaterThan(0);
      result.firstResponse.headers['x-unique-output'].should.not.eql(result.secondResponse.headers['x-unique-output']);

      result.firstResponse.headers['x-cache'].should.eql('MISS');
      result.secondResponse.headers['x-cache'].should.eql('MISS');

      done(error, result);
    });
  }

  function actsLikeCacheable(baseUrl, options, done) {
    makeDuplicateRequests(baseUrl, options, function(error, result) {
      if(!options.skipBodyCompare) {
        result.firstBody.length.should.be.greaterThan(0);
        result.firstBody.should.eql(result.secondBody);
      }

      result.firstResponse.headers['x-unique-output'].length.should.be.greaterThan(0);
      result.firstResponse.headers['x-unique-output'].should.eql(result.secondResponse.headers['x-unique-output']);

      result.firstResponse.headers['x-cache'].should.eql('MISS');
      result.secondResponse.headers['x-cache'].should.eql('HIT');

      done(error, result);
    });
  }

  function actsLikeThunderingHerd(baseUrl, options, done) {
    var id = _.uniqueId().toString();
    var url = baseUrl + id;
    options = _.merge({
      method: 'GET',
    }, options, { agentOptions: { maxSockets: 150 } });

    async.times(50, function(index, callback) {
      request(url, options, function(error, response, body) {
        callback(error, { body: body, responseCode: response.statusCode });
      });
    }, function(error, results) {
      results.length.should.eql(50);

      var responseCodes = _.pluck(results, 'responseCode');
      var bodies = _.pluck(results, 'body');

      request.get('http://127.0.0.1:9442/backend_call_count?id=' + id, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        body.should.eql('50');

        bodies.length.should.eql(50);
        _.uniq(responseCodes).should.eql([200]);
        _.uniq(bodies).length.should.eql(50);

        done();
      });
    });
  }

  function actsLikeNotThunderingHerd(baseUrl, options, done) {
    var id = _.uniqueId().toString();
    var url = baseUrl + id;
    options = _.merge({
      method: 'GET',
    }, options, { agentOptions: { maxSockets: 150 } });

    async.times(50, function(index, callback) {
      request(url, options, function(error, response, body) {
        callback(error, { body: body, responseCode: response.statusCode });
      });
    }, function(error, results) {
      should.not.exist(error);
      results.length.should.eql(50);

      var responseCodes = _.pluck(results, 'responseCode');
      var bodies = _.pluck(results, 'body');

      request.get('http://127.0.0.1:9442/backend_call_count?id=' + id, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        body.should.eql('1');

        bodies.length.should.eql(50);
        _.uniq(responseCodes).should.eql([200]);
        _.uniq(bodies).length.should.eql(1);

        done();
      });
    });
  }

  it('does not cache items by default', function(done) {
    actsLikeNotCacheable('http://localhost:9080/cacheable-but-not/', this.options, done);
  });

  it('acknowledges cache-control max-age headers', function(done) {
    actsLikeCacheable('http://localhost:9080/cacheable-cache-control-max-age/', this.options, done);
  });

  it('acknowledges cache-control s-maxage headers', function(done) {
    actsLikeCacheable('http://localhost:9080/cacheable-cache-control-s-maxage/', this.options, done);
  });

  it('acknowledges cache-control headers case insensitively', function(done) {
    actsLikeCacheable('http://localhost:9080/cacheable-cache-control-case-insensitive/', this.options, done);
  });

  it('acknowledges expires headers', function(done) {
    actsLikeCacheable('http://localhost:9080/cacheable-expires/', this.options, done);
  });

  it('acknowledges surrogate-control max-age headers', function(done) {
    actsLikeCacheable('http://localhost:9080/cacheable-surrogate-control-max-age/', this.options, done);
  });

  it('acknowledges surrogate-control headers case insensitively', function(done) {
    actsLikeCacheable('http://localhost:9080/cacheable-surrogate-control-case-insensitive/', this.options, done);
  });

  it('surrogate-control headers take precedence over cache-control headers', function(done) {
    actsLikeCacheable('http://localhost:9080/cacheable-surrogate-control-and-cache-control/', this.options, done);
  });

  it('does not return surrogate-control headers to the client', function(done) {
    request.get('http://localhost:9080/cacheable-surrogate-control-max-age/' + _.uniqueId(), this.options, function(error, response) {
      should.not.exist(response.headers['surrogate-control']);
      done();
    });
  });

  it('surrogate-control headers do not interfere with cache-control headers being returned', function(done) {
    request.get('http://localhost:9080/cacheable-surrogate-control-and-cache-control/' + _.uniqueId(), this.options, function(error, response) {
      response.headers['cache-control'].should.eql('max-age=0, private, must-revalidate');
      done();
    });
  });

  describe('frontends with different paths but colliding backend paths', function() {
    it('distinguishes between backends with identical paths but different hosts', function(done) {
      var uniqueId = _.uniqueId();
      var fooUrl = 'http://localhost:9080/cacheable-backend-host/prefix/foo/' + uniqueId;
      var barUrl = 'http://localhost:9080/cacheable-backend-host/prefix/bar/' + uniqueId;

      async.series([
        function(next) {
          request(fooUrl, this.options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            response.headers['x-cache'].should.eql('MISS');
            body.should.eql('foo.example');
            next();
          });
        }.bind(this),
        function(next) {
          request(barUrl, this.options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            response.headers['x-cache'].should.eql('MISS');
            body.should.eql('bar.example');
            next();
          });
        }.bind(this),
      ], done);
    });

    it('distinguishes between backends with identical paths and hosts, but belonging to different API backends (separated by ports)', function(done) {
      var uniqueId = _.uniqueId();
      var fooUrl = 'http://localhost:9080/cacheable-backend-port/prefix/foo/' + uniqueId;
      var barUrl = 'http://localhost:9080/cacheable-backend-port/prefix/bar/' + uniqueId;

      async.series([
        function(next) {
          request(fooUrl, this.options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            response.headers['x-cache'].should.eql('MISS');
            body.should.eql('9444');
            next();
          });
        }.bind(this),
        function(next) {
          request(barUrl, this.options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            response.headers['x-cache'].should.eql('MISS');
            body.should.eql('9441');
            next();
          });
        }.bind(this),
      ], done);
    });
  });

  describe('cacheable http methods', function() {
    ['GET'].forEach(function(method) {
      it('allows caching for ' + method + ' requests', function(done) {
        var options = _.merge({}, this.options, { method: method });
        actsLikeCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
      });
    });

    ['HEAD'].forEach(function(method) {
      // TrafficServer doesn't seem to allow direct caching of a raw HEAD
      // request, but it does allow it to use the corresponding GET response
      // cache. So this probably isn't a huge deal.
      if(global.CACHING_SERVER !== 'trafficserver') {
        it('allows caching for ' + method + ' requests', function(done) {
          var options = _.merge({}, this.options, {
            method: method,
            skipBodyCompare: true,
          });
          actsLikeCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
        });
      }

      it('returns a cached ' + method + ' request when a GET request is made first', function(done) {
        var options = _.merge({}, this.options, {
          method: 'GET',
          secondCallOverrides: {
            method: method,
          },
          skipBodyCompare: true,
        });
        actsLikeCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
      });
    });
  });

  describe('non-cacheable http methods', function() {
    ['POST', 'PUT', 'PATCH', 'OPTIONS', 'DELETE'].forEach(function(method) {
      it('does not allow caching for ' + method + ' requests', function(done) {
        var options = _.merge({}, this.options, { method: method });
        actsLikeNotCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
      });

      it('does not cache ' + method + ' requests when a GET request is made first', function(done) {
        var options = _.merge({}, this.options, {
          method: 'GET',
          secondCallOverrides: {
            method: method,
          },
        });

        actsLikeNotCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
      });
    });
  });

  describe('cache response headers', function() {
    it('returns X-Cache: HIT for cache hits', function(done) {
      var id = _.uniqueId();
      request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function() {
        request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function(error, response) {
          response.headers['x-cache'].should.eql('HIT');
          done();
        });
      }.bind(this));
    });

    it('returns X-Cache: HIT for in-memory cache hits', function(done) {
      var id = _.uniqueId();
      // TrafficServer has two different categories for cache hits internally,
      // in-memory RAM hits and disk hits. So make sure we account for both my
      // making 3 requests.
      request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function() {
        request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function() {
          request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function(error, response) {
            response.headers['x-cache'].should.eql('HIT');
            done();
          });
        }.bind(this));
      }.bind(this));
    });

    it('returns X-Cache: MISS for cache misses', function(done) {
      var id = _.uniqueId();
      request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function(error, response) {
        response.headers['x-cache'].should.eql('MISS');
        done();
      });
    });

    it('returns X-Cache: HIT if underlying backend server reports a cache hit', function(done) {
      var id = _.uniqueId();
      request.get('http://localhost:9080/cacheable-backend-reports-cached/' + id, this.options, function(error, response) {
        response.headers['x-cache'].should.eql('HIT');
        done();
      });
    });

    it('increases the age in the response over time for cached responses', function(done) {
      this.timeout(6000);

      var id = _.uniqueId();
      request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function(error, response, firstBody) {
        parseInt(response.headers['age']).should.be.gte(0);
        parseInt(response.headers['age']).should.be.lte(1);

        setTimeout(function() {
          request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function(error, response, body) {
            body.should.eql(firstBody);
            parseInt(response.headers['age']).should.be.gte(1);
            parseInt(response.headers['age']).should.be.lte(2);

            setTimeout(function() {
              request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function(error, response, body) {
                body.should.eql(firstBody);
                parseInt(response.headers['age']).should.be.gte(2);
                parseInt(response.headers['age']).should.be.lte(3);

                setTimeout(function() {
                  request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function(error, response, body) {
                    body.should.eql(firstBody);
                    parseInt(response.headers['age']).should.be.gte(3);
                    parseInt(response.headers['age']).should.be.lte(4);

                    done();
                  });
                }.bind(this), 1100);
              }.bind(this));
            }.bind(this), 1100);
          }.bind(this));
        }.bind(this), 1100);
      }.bind(this));
    });

    it('returns original value for Age header from the backend server and then increments based off that for the local cache', function(done) {
      this.timeout(6000);

      var id = _.uniqueId();
      request.get('http://localhost:9080/cacheable-backend-reports-cached/' + id, this.options, function(error, response, firstBody) {
        parseInt(response.headers['age']).should.be.gte(3);
        parseInt(response.headers['age']).should.be.lte(4);

        setTimeout(function() {
          request.get('http://localhost:9080/cacheable-backend-reports-cached/' + id, this.options, function(error, response, body) {
            body.should.eql(firstBody);
            parseInt(response.headers['age']).should.be.gte(4);
            parseInt(response.headers['age']).should.be.lte(5);

            setTimeout(function() {
              request.get('http://localhost:9080/cacheable-backend-reports-cached/' + id, this.options, function(error, response, body) {
                body.should.eql(firstBody);
                parseInt(response.headers['age']).should.be.gte(7);
                parseInt(response.headers['age']).should.be.lte(8);

                done();
              });
            }.bind(this), 3100);
          }.bind(this));
        }.bind(this), 1100);
      }.bind(this));
    });

    it('returns original value for X-Cache from the backend server until the response becomes locally cached', function(done) {
      var id = _.uniqueId();
      request.get('http://localhost:9080/cacheable-backend-reports-not-cached/' + id, this.options, function(error, response) {
        response.headers['x-cache'].should.eql('BACKEND-MISS');
        request.get('http://localhost:9080/cacheable-backend-reports-not-cached/' + id, this.options, function(error, response) {
          response.headers['x-cache'].should.eql('HIT');
          done();
        });
      }.bind(this));
    });
  });

  // FIXME: The Traffic Server collapsed_connection plugin currently requires
  // the Cache-Control explicitly be marked as "public" for it to do its
  // collapsing:
  // https://github.com/apache/trafficserver/blob/a90403e9f6220f5511cb9d1523a4db8c27a9316f/plugins/experimental/collapsed_connection/collapsed_connection.cc#L603
  //
  // I think this is incorrect behavior and the plugin should be updated to use
  // the newer TSHttpTxnIsCacheable API:
  // https://issues.apache.org/jira/browse/TS-1622 This will allow the plugin
  // to more accurately know whether the response is cacheable according to the
  // more complex TrafficServer logic. We should see about submitting a pull
  // request or filing an issue.
  xit('prevents thundering herds for cacheable requests', function(done) {
    this.timeout(3000);
    actsLikeNotThunderingHerd('http://localhost:9080/cacheable-thundering-herd/', this.options, done);
  });

  it('prevents thundering herds for cacheable requests (cache control public)', function(done) {
    this.timeout(3000);
    actsLikeNotThunderingHerd('http://localhost:9080/cacheable-thundering-herd-public/', this.options, done);
  });

  it('allows thundering herds for potentially cacheable requests that return cache-control private headers', function(done) {
    this.timeout(5000);
    actsLikeThunderingHerd('http://localhost:9080/cacheable-thundering-herd-private/', this.options, done);
  });

  it('allows thundering herds for potentially cacheable requests that explicitly forbid caching', function(done) {
    this.timeout(5000);
    actsLikeThunderingHerd('http://localhost:9080/cacheable-but-cache-forbidden-thundering-herd/', this.options, done);
  });

  it('allows thundering herds for potentially cacheable requests that have no explicit cache control', function(done) {
    this.timeout(5000);
    actsLikeThunderingHerd('http://localhost:9080/cacheable-but-no-explicit-cache-thundering-herd/', this.options, done);
  });

  it('allows thundering herds for non-cacheable requests', function(done) {
    this.timeout(3000);
    var options = _.merge({ method: 'POST' }, this.options);
    actsLikeThunderingHerd('http://localhost:9080/cacheable-thundering-herd/', options, done);
  });

  it('does not cache requests with externally sent authorization header', function(done) {
    var options = _.merge({
      headers: {
        'Authorization': 'foo',
      },
    }, this.options);
    actsLikeNotCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
  });

  it('caches requests that add an http basic auth header at the proxy layer', function(done) {
    actsLikeCacheable('http://localhost:9080/add-auth-header/cacheable-cache-control-max-age/', this.options, done);
  });

  it('passes the authorization header to the backend when the auth header is added at the proxy layer (despite being stripped for caching purposes)', function(done) {
    request.get('http://localhost:9080/add-auth-header/info/', this.options, function(error, response, body) {
      var data = JSON.parse(body);
      data.basic_auth_username.should.eql('somebody');
      data.basic_auth_password.should.eql('secret');
      done();
    });
  });

  it('strips the internal X-Api-Umbrella-Orig-Authorization header before sending the request to the backend', function(done) {
    request.get('http://localhost:9080/add-auth-header/info/', this.options, function(error, response, body) {
      var data = JSON.parse(body);
      should.not.exist(data.headers['x-api-umbrella-orig-authorization']);
      done();
    });
  });

  it('strips the internal X-Api-Umbrella-Allow-Authorization-Caching header before sending the request to the backend', function(done) {
    request.get('http://localhost:9080/add-auth-header/info/', this.options, function(error, response, body) {
      var data = JSON.parse(body);
      should.not.exist(data.headers['x-api-umbrella-allow-authorization-caching']);
      done();
    });
  });

  it('caches requests that pass the api key via the authorization header', function(done) {
    actsLikeCacheable('http://' + this.apiKey + ':@localhost:9080/cacheable-cache-control-max-age/', this.options, done);
  });

  it('does not cache requests with an externally sent authorization header that also set our internally used X-Api-Umbrella-Allow-Authorization-Caching header', function(done) {
    var options = _.merge({
      headers: {
        'Authorization': 'foo',
        'X-Api-Umbrella-Allow-Authorization-Caching': 'true',
      },
    }, this.options);
    actsLikeNotCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
  });

  it('does not cache requests that add an http basic auth header at the proxy layer, but also have other cache preventing charachteristics (for example, unknown cookie)', function(done) {
    var options = _.merge({
      headers: {
        'Cookie': 'foo=bar',
      },
    }, this.options);
    actsLikeNotCacheable('http://localhost:9080/add-auth-header/cacheable-cache-control-max-age/', options, done);
  });

  it('does cache requests with analytics cookies', function(done) {
    var options = _.merge({
      headers: {
        'Cookie': '__utma=foo',
      },
    }, this.options);
    actsLikeCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
  });

  it('does not cache requests with unknown cookies', function(done) {
    var options = _.merge({
      headers: {
        'Cookie': 'foo=bar',
      },
    }, this.options);
    actsLikeNotCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
  });

  it('does not cache requests with analytics and unknown cookies', function(done) {
    var options = _.merge({
      headers: {
        'Cookie': 'foo=bar; __utma=foo;',
      },
    }, this.options);
    actsLikeNotCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
  });

  it('ignores client no-cache headers on the request', function(done) {
    var options = _.merge({
      headers: {
        'Cache-Control': 'no-cache',
      },
    }, this.options);
    actsLikeCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
  });

  it('does not cache responses that set cookies', function(done) {
    actsLikeNotCacheable('http://localhost:9080/cacheable-set-cookie/', this.options, done);
  });

  it('does not cache responses that expires at 0', function(done) {
    var options = _.merge({}, this.options);
    if(global.CACHING_SERVER === 'trafficserver') {
      _.merge(options, {
        // TrafficServer has a bug where Expires: 0 and Expires: Past Date
        // headers are actually cached for less than a second. Probably not a
        // huge deal, but this would be nice if they fixed it. In the meantime,
        // we'll sleep 1 second between the requests.
        // See: https://issues.apache.org/jira/browse/TS-2961
        secondCallSleep: 1000,
      });
    }

    actsLikeNotCacheable('http://localhost:9080/cacheable-expires-0/', options, done);
  });

  it('does not cache responses that expires in the past', function(done) {
    var options = _.merge({}, this.options);
    if(global.CACHING_SERVER === 'trafficserver') {
      _.merge(options, {
        // TrafficServer has a bug where Expires: 0 and Expires: Past Date
        // headers are actually cached for less than a second. Probably not a
        // huge deal, but this would be nice if they fixed it. In the meantime,
        // we'll sleep 1 second between the requests.
        // See: https://issues.apache.org/jira/browse/TS-2961
        secondCallSleep: 1000,
      });
    }

    actsLikeNotCacheable('http://localhost:9080/cacheable-expires-past/', options, done);
  });

  it('does not cache responses that contain www-authenticate headers', function(done) {
    actsLikeNotCacheable('http://localhost:9080/cacheable-www-authenticate/', this.options, done);
  });

  it('does cache requests that contain dynamic looking urls', function(done) {
    actsLikeCacheable('http://localhost:9080/cacheable-dynamic/test.cgi?foo=bar&test=test&id=', this.options, done);
  });

  it('delivers the same cached response for users with different api keys (api keys are not part of the cache key url)', function(done) {
    var baseUrl = 'http://localhost:9080/cacheable-cache-control-max-age/' + _.uniqueId();
    var firstApiKey = this.apiKey;
    Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
      var secondApiKey = user.api_key;

      request.get(baseUrl + '?api_key=' + firstApiKey, function(error, response, firstBody) {
        response.statusCode.should.eql(200);

        request.get(baseUrl + '?api_key=' + secondApiKey, function(error, response, secondBody) {
          response.statusCode.should.eql(200);

          firstBody.toString().should.eql(secondBody.toString());
          done();
        });
      });
    });
  });

  describe('gzip', function() {
    describe('cached gzip responses do not mix with uncompressed responses', function() {
      function itBehavesLikeGzip() {
        describe('first request is compressed ("Accept-Encoding: gzip" header)', function() {
          beforeEach(function() {
            this.options = _.merge({}, this.options, { gzip: true });
          });

          it('delivers a gzipped response when the second request is compressed ("Accept-Encoding: gzip" header)', function(done) {
            var options = _.merge({}, this.options, {
              secondCallOverrides: {
                gzip: true,
              },
            });

            makeDuplicateRequests(this.url, options, function(error, result) {
              result.firstResponse.headers['content-encoding'].should.eql('gzip');
              result.secondResponse.headers['content-encoding'].should.eql('gzip');
              done();
            });
          });

          it('delivers an uncompressed response when the second request is compressed ("Accept-Encoding: gzip" header)', function(done) {
            var options = _.merge({}, this.options, {
              secondCallOverrides: {
                gzip: false,
              },
            });

            makeDuplicateRequests(this.url, options, function(error, result) {
              result.firstResponse.headers['content-encoding'].should.eql('gzip');
              should.not.exist(result.secondResponse.headers['content-encoding']);
              done();
            });
          });
        });

        describe('first request is uncompressed (no "Accept-Encoding" header)', function() {
          beforeEach(function() {
            this.options = _.merge({}, this.options, { gzip: false });
          });

          it('delivers a gzipped response when the second request is compressed ("Accept-Encoding: gzip" header)', function(done) {
            var options = _.merge({}, this.options, {
              secondCallOverrides: {
                gzip: true,
              },
            });

            makeDuplicateRequests(this.url, options, function(error, result) {
              should.not.exist(result.firstResponse.headers['content-encoding']);
              result.secondResponse.headers['content-encoding'].should.eql('gzip');
              done();
            });
          });

          it('delivers an uncompressed response when the second request is uncompressed (no "Accept-Encoding" header)', function(done) {
            var options = _.merge({}, this.options, {
              secondCallOverrides: {
                gzip: false,
              },
            });

            makeDuplicateRequests(this.url, options, function(error, result) {
              should.not.exist(result.firstResponse.headers['content-encoding']);
              should.not.exist(result.secondResponse.headers['content-encoding']);
              done();
            });
          });
        });
      }

      describe('backend does not support gzipping (returns no "Vary" header)', function() {
        beforeEach(function() {
          this.url = 'http://localhost:9080/cacheable-compressible/';
        });

        itBehavesLikeGzip();
      });

      describe('backend supports gzipping itself (always returns "Vary: Accept-Encoding" header)', function() {
        beforeEach(function() {
          this.url = 'http://localhost:9080/cacheable-pre-gzip/';
        });

        itBehavesLikeGzip();
      });

      describe('backend does not support gzipping, but still returns vary header (always returns "Vary: Accept-Encoding" header)', function() {
        beforeEach(function() {
          this.url = 'http://localhost:9080/cacheable-vary-accept-encoding/';
        });

        itBehavesLikeGzip();
      });

      describe('backend returns multiple very headers and supports gzipping itself (always returns "Vary: X-Foo,Accept-Encoding,Accept" header)', function() {
        beforeEach(function() {
          this.url = 'http://localhost:9080/cacheable-pre-gzip-multiple-vary/';
        });

        itBehavesLikeGzip();
      });

      describe('backend returns multiple very headers and does not support gzipping, but still returns vary header (always returns "Vary: X-Foo,Accept-Encoding,Accept" header)', function() {
        beforeEach(function() {
          this.url = 'http://localhost:9080/cacheable-vary-accept-encoding-multiple/';
        });

        itBehavesLikeGzip();
      });
    });

    // Ideally we would return a cached response regardless of whether the
    // first request was gzipped or not. But for now, we don't support this,
    // and the gzip and non-gzipped versions must be requested and cached
    // separately.
    //
    // Varnish supports this more optimized behavior, but it does so by forcing
    // gzip to always be on, then only caching the gzipped version, and then
    // un-gzipping it on the fly for each non-gzip client. For our API traffic,
    // it seems that gzip being enabled is actually the minority of requests
    // (only 40% based on some current production stats), so forcing each
    // request to be un-gzipped on the fly seems like unnecessary overhead
    // given our current usage.
    //
    // In our explorations of TrafficServer, this is unsupported:
    // http://permalink.gmane.org/gmane.comp.apache.trafficserver.user/4191
    //
    // It's possible we might want to revisit this if we decide saving the
    // backend bandwidth is more efficient than unzipping each request on the
    // fly for each non-gzip client.
    xdescribe('optimized gzip behavior', function() {
      function itBehavesLikeOptimizedGzip() {
        describe('first request is compressed ("Accept-Encoding: gzip" header)', function() {
          beforeEach(function() {
            this.options = _.merge({}, this.options, { gzip: true });
          });

          it('delivers a cached gzipped response when the second request is compressed ("Accept-Encoding: gzip" header)', function(done) {
            var options = _.merge({}, this.options, {
              secondCallOverrides: {
                gzip: true,
              },
            });

            actsLikeCacheable(this.url, options, function(error, result) {
              result.firstResponse.headers['content-encoding'].should.eql('gzip');
              result.secondResponse.headers['content-encoding'].should.eql('gzip');
              done();
            });
          });

          it('delivers a cached uncompressed response when the second request is uncompressed (no "Accept-Encoding" header)', function(done) {
            var options = _.merge({}, this.options, {
              secondCallOverrides: {
                gzip: false,
              },
            });

            actsLikeCacheable(this.url, options, function(error, result) {
              result.firstResponse.headers['content-encoding'].should.eql('gzip');
              should.not.exist(result.secondResponse.headers['content-encoding']);
              done();
            });
          });
        });

        describe('first request is uncompressed (no "Accept-Encoding" header)', function() {
          beforeEach(function() {
            this.options = _.merge({}, this.options, { gzip: false });
          });

          it('delivers a cached gzipped response when the second request is compressed ("Accept-Encoding: gzip" header)', function(done) {
            var options = _.merge({}, this.options, {
              secondCallOverrides: {
                gzip: true,
              },
            });

            actsLikeCacheable(this.url, options, function(error, result) {
              should.not.exist(result.firstResponse.headers['content-encoding']);
              result.secondResponse.headers['content-encoding'].should.eql('gzip');
              done();
            });
          });

          it('delivers a cached uncompressed response when the second request is uncompressed (no "Accept-Encoding" header)', function(done) {
            var options = _.merge({}, this.options, {
              secondCallOverrides: {
                gzip: false,
              },
            });

            actsLikeCacheable(this.url, options, function(error, result) {
              should.not.exist(result.firstResponse.headers['content-encoding']);
              should.not.exist(result.secondResponse.headers['content-encoding']);
              done();
            });
          });
        });
      }

      describe('backend does not support gzipping (returns no "Vary" header)', function() {
        beforeEach(function() {
          this.url = 'http://localhost:9080/cacheable-compressible/';
        });

        itBehavesLikeOptimizedGzip();
      });

      describe('backend supports gzipping itself (always returns "Vary: Accept-Encoding" header)', function() {
        beforeEach(function() {
          this.url = 'http://localhost:9080/cacheable-pre-gzip/';
        });

        itBehavesLikeOptimizedGzip();
      });

      describe('backend does not support gzipping, but still returns vary header (always returns "Vary: Accept-Encoding" header)', function() {
        beforeEach(function() {
          this.url = 'http://localhost:9080/cacheable-vary-accept-encoding/';
        });

        itBehavesLikeOptimizedGzip();
      });

      describe('backend returns multiple very headers and supports gzipping itself (always returns "Vary: X-Foo,Accept-Encoding,Accept" header)', function() {
        beforeEach(function() {
          this.url = 'http://localhost:9080/cacheable-pre-gzip-multiple-vary/';
        });

        itBehavesLikeOptimizedGzip();
      });

      describe('backend returns multiple very headers and does not support gzipping, but still returns vary header (always returns "Vary: X-Foo,Accept-Encoding,Accept" header)', function() {
        beforeEach(function() {
          this.url = 'http://localhost:9080/cacheable-vary-accept-encoding-multiple/';
        });

        itBehavesLikeOptimizedGzip();
      });
    });
  });

  describe('vary', function() {
    it('caches requests with different custom headers if the response doesn\'t vary on the header', function(done) {
      var options = _.merge({}, this.options, {
        headers: {
          'X-Custom': 'foo',
        },
        secondCallOverrides: {
          headers: {
            'X-Custom': 'bar',
          },
        },
      });

      actsLikeCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
    });

    it('does not cache requests with different custom headers if the response varies on the header', function(done) {
      var options = _.merge({}, this.options, {
        headers: {
          'X-Custom': 'foo',
        },
        secondCallOverrides: {
          headers: {
            'X-Custom': 'bar',
          },
        },
      });

      actsLikeNotCacheable('http://localhost:9080/cacheable-vary-x-custom/', options, done);
    });

    it('caches identical requests if the response varies on a header that is not passed in', function(done) {
      actsLikeCacheable('http://localhost:9080/cacheable-vary-x-custom/', this.options, done);
    });

    it('caches requests that have the same header value on the header that is varied on', function(done) {
      var options = _.merge({}, this.options, {
        headers: {
          'X-Custom': 'foo',
        },
      });

      actsLikeCacheable('http://localhost:9080/cacheable-vary-x-custom/', options, done);
    });

    describe('when responses vary on multiple headers', function() {
      it('caches requests if the varied headers are the same', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Accept': 'text/plain',
            'Accept-Language': 'en-US',
            'X-Foo': 'bar',
          },
        });

        actsLikeCacheable('http://localhost:9080/cacheable-multiple-vary/', options, done);
      });

      it('caches requests if a non-varied header differs', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Accept': 'text/plain',
            'Accept-Language': 'en-US',
            'X-Foo': 'bar',
          },
          secondCallOverrides: {
            headers: {
              'X-Bar': 'foo',
            },
          },
        });

        actsLikeCacheable('http://localhost:9080/cacheable-multiple-vary/', options, done);
      });

      it('does not cache requests if at least one varied header differs', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Accept': 'text/plain',
            'Accept-Language': 'en-US',
            'X-Foo': 'bar',
          },
          secondCallOverrides: {
            headers: {
              'Accept': 'application/json',
            },
          },
        });

        actsLikeNotCacheable('http://localhost:9080/cacheable-multiple-vary/', options, done);
      });
    });

    describe('when responses vary on multiple headers, inclding accept-encoding', function() {
      it('caches requests if the varied headers are the same', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Accept': 'text/plain',
            'Accept-Language': 'en-US',
            'X-Foo': 'bar',
          },
          gzip: true,
        });

        actsLikeCacheable('http://localhost:9080/cacheable-multiple-vary-with-accept-encoding/', options, done);
      });

      it('caches requests if a non-varied header differs', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Accept': 'text/plain',
            'Accept-Language': 'en-US',
            'X-Foo': 'bar',
          },
          gzip: true,
          secondCallOverrides: {
            headers: {
              'X-Bar': 'foo',
            },
          },
        });

        actsLikeCacheable('http://localhost:9080/cacheable-multiple-vary-with-accept-encoding/', options, done);
      });

      it('does not cache requests if at least one varied header differs', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Accept': 'text/plain',
            'Accept-Language': 'en-US',
            'X-Foo': 'bar',
          },
          gzip: true,
          secondCallOverrides: {
            headers: {
              'Accept': 'application/json',
            },
          },
        });

        actsLikeNotCacheable('http://localhost:9080/cacheable-multiple-vary-with-accept-encoding/', options, done);
      });
    });
  });
});
