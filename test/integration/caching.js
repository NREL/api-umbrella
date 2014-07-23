'use strict';

require('../test_helper');

var _ = require('lodash'),
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
    request.get(baseUrl + id, options, function(error, response) {
      response.statusCode.should.eql(200);
      response.headers['age'].should.eql('0');
      global.cachableCallCounts[id].should.eql(1);

      request.get(baseUrl + id, options, function(error, response) {
        response.statusCode.should.eql(200);
        response.headers['age'].should.eql('0');
        global.cachableCallCounts[id].should.eql(2);

        done();
      });
    });
  }

  function actsLikeCacheable(url, options, done) {
    var id = _.uniqueId();
    request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, options, function(error, response) {
      response.statusCode.should.eql(200);
      global.cachableCallCounts[id].should.eql(1);

      request.get('http://localhost:9080/cacheable-cache-control-max-age/' + id, options, function(error, response) {
        response.statusCode.should.eql(200);
        global.cachableCallCounts[id].should.eql(1);

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

  it('acknowledges expires headers', function(done) {
    actsLikeCacheable('http://localhost:9080/cacheable-expires/', this.options, done);
  });

  it('acknowledges surrogate-control max-age headers', function(done) {
    actsLikeCacheable('http://localhost:9080/cacheable-surrogate-control-max-age/', this.options, done);
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

  it('prevents thundering herds for potentially cacheable requests', function() {
  });

  it('allows thundering herds for non-cacheable requests', function() {
  });

  it('does not cache requests with authorization header', function() {
  });

  it('does cache requests with public cookies', function() {
  });

  it('does not cache requests with private cookies', function() {
  });

  it('does not cache requests with public and private cookies', function() {
  });

  it('ignores client no-cache headers on the request', function() {
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

  it('delivers a cached gzip response when the request was first made with gzip', function() {
  });

  it('delivers a cached gzip response when the request was first made without gzip', function() {
  });

  it('delivers a cached non-gzipped response when the request was first made wth gzip', function() {
  });

  it('delivers a cached non-gzipped response when the request was first made without gzip', function() {
  });

  it('normalizes gzip headers', function() {
  });

  it('vary/accept encoding stuff', function() {
  });
});
