'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    Factory = require('factory-lady'),
    request = require('request');

describe('caching', function() {
  beforeEach(function(done) {
    Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
      this.apiKey = user.api_key;
      this.options = {
        headers: {
          'X-Api-Key': this.apiKey,
        },
      };

      done();
    }.bind(this));
  });

  function actsLikeNotCacheable(baseUrl, options, done) {
    var id = _.uniqueId();
    options = _.merge({
      method: 'GET',
    }, options);

    request(baseUrl + id, options, function(error, response, firstBody) {
      response.statusCode.should.eql(200);
      if(response.headers['age']) {
        response.headers['age'].should.eql('0');
      } else {
        should.not.exist(response.headers['age']);
      }

      request.get(baseUrl + id, options, function(error, response, secondBody) {
        response.statusCode.should.eql(200);
        if(response.headers['age']) {
          response.headers['age'].should.eql('0');
        } else {
          should.not.exist(response.headers['age']);
        }

        firstBody.should.not.eql(secondBody);

        done();
      });
    });
  }

  function actsLikeCacheable(baseUrl, options, done) {
    var id = _.uniqueId();
    request.get(baseUrl + id, options, function(error, response, firstBody) {
      response.statusCode.should.eql(200);

      request.get(baseUrl + id, options, function(error, response, secondBody) {
        response.statusCode.should.eql(200);
        firstBody.should.eql(secondBody);

        done();
      });
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
        response.statusCode.should.eql(200);
        callback(null, body);
      });
    }, function(error, bodies) {
      global.backendCallCounts[id].should.eql(50);
      bodies.length.should.eql(50);
      _.uniq(bodies).length.should.eql(50);
      done();
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
        response.statusCode.should.eql(200);
        callback(null, body);
      });
    }, function(error, bodies) {
      global.backendCallCounts[id].should.eql(1);
      bodies.length.should.eql(50);
      _.uniq(bodies).length.should.eql(1);
      done();
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

  // FIXME: Currently failing in Varnish. Need to likely change how the
  // Surrogate-Control header gets applied.
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

  describe('cacheable http methods', function() {
    ['GET', 'HEAD'].forEach(function(method) {
      it('allows caching for ' + method + ' requests', function(done) {
        var options = _.merge({ method: method }, this.options);
        actsLikeCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
      });
    });
  });

  describe('non-cacheable http methods', function() {
    ['POST', 'PUT', 'PATCH', 'OPTIONS', 'DELETE'].forEach(function(method) {
      it('does not allow caching for ' + method + ' requests', function(done) {
        var options = _.merge({ method: method }, this.options);
        actsLikeNotCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
      });
    });
  });

  it('increases the age in the response over time for cached responses', function(done) {
    this.timeout(6000);

    var id = _.uniqueId();
    request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function(error, response) {
      parseInt(response.headers['age']).should.eql(0);

      setTimeout(function() {
        request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function(error, response) {
          parseInt(response.headers['age']).should.be.gte(1);
          parseInt(response.headers['age']).should.be.lte(2);

          setTimeout(function() {
            request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function(error, response) {
              parseInt(response.headers['age']).should.be.gte(2);
              parseInt(response.headers['age']).should.be.lte(3);

              setTimeout(function() {
                request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, this.options, function(error, response) {
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

  it('prevents thundering herds for cacheable requests', function(done) {
    this.timeout(3000);
    actsLikeNotThunderingHerd('http://localhost:9080/cacheable-thundering-herd/', this.options, done);
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

  it('does not cache requests with authorization header', function(done) {
    var options = _.merge({
      headers: {
        'Authorization': 'foo',
      },
    }, this.options);
    actsLikeNotCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
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

  it('does not cache responses that set cookies', function() {
  });

  it('does not cache responses that expires at 0', function() {
  });

  it('does not cache responses that expires in the past', function() {
  });

  it('does not cache responses that contain www-authenticate headers', function() {
  });

  it('does cache requests that contain dynamic looking urls', function() {
  });

  it('delivers the same cached response for users with different api keys (api keys are not part of the cache key url)', function() {
  });

  it('delivers a cached gzip response when the request was first made with gzip', function(done) {
    var url = 'http://localhost:9080/cacheable-compressible/' + _.uniqueId();
    var options = _.merge({}, this.options, { gzip: true });

    request.get(url, options, function(error, response, firstBody) {
      response.statusCode.should.eql(200);
      response.headers['content-encoding'].should.eql('gzip');

      request.get(url, options, function(error, response, secondBody) {
        response.statusCode.should.eql(200);
        response.headers['content-encoding'].should.eql('gzip');

        firstBody.toString().should.eql(secondBody.toString());
        done();
      });
    });
  });

  it('delivers a cached gzip response when the request was first made without gzip', function(done) {
    var url = 'http://localhost:9080/cacheable-compressible/' + _.uniqueId();
    var options = _.merge({}, this.options, { gzip: false });

    request.get(url, options, function(error, response, firstBody) {
      response.statusCode.should.eql(200);
      should.not.exist(response.headers['content-encoding']);

      _.merge(options, { gzip: true });

      request.get(url, options, function(error, response, secondBody) {
        response.statusCode.should.eql(200);
        response.headers['content-encoding'].should.eql('gzip');

        firstBody.toString().should.eql(secondBody.toString());
        done();
      });
    });
  });

  it('delivers a cached non-gzipped response when the request was first made with gzip', function(done) {
    var url = 'http://localhost:9080/cacheable-compressible/' + _.uniqueId();
    var options = _.merge({}, this.options, { gzip: true });

    request.get(url, options, function(error, response, firstBody) {
      response.statusCode.should.eql(200);
      response.headers['content-encoding'].should.eql('gzip');

      _.merge(options, { gzip: false });

      request.get(url, options, function(error, response, secondBody) {
        response.statusCode.should.eql(200);
        should.not.exist(response.headers['content-encoding']);

        firstBody.toString().should.eql(secondBody.toString());
        done();
      });
    });
  });

  it('delivers a cached non-gzipped response when the request was first made without gzip', function(done) {
    var url = 'http://localhost:9080/cacheable-compressible/' + _.uniqueId();
    var options = _.merge({}, this.options, {
      headers: {
        'Accept-Encoding': '',
      },
    });

    request.get(url, options, function(error, response, firstBody) {
      response.statusCode.should.eql(200);
      should.not.exist(response.headers['content-encoding']);

      request.get(url, options, function(error, response, secondBody) {
        response.statusCode.should.eql(200);
        should.not.exist(response.headers['content-encoding']);

        firstBody.toString().should.eql(secondBody.toString());
        done();
      });
    });
  });

  it('normalizes gzip headers', function() {
  });

  it('vary/accept encoding stuff', function() {
  });
});
