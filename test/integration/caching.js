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
      if(result.firstResponse.headers['age']) {
        result.firstResponse.headers['age'].should.eql('0');
      } else {
        should.not.exist(result.firstResponse.headers['age']);
      }

      if(result.secondResponse.headers['age']) {
        result.secondResponse.headers['age'].should.eql('0');
      } else {
        should.not.exist(result.secondResponse.headers['age']);
      }

      result.firstBody.length.should.be.greaterThan(0);
      result.firstBody.should.not.eql(result.secondBody);

      done(error, result);
    });
  }

  function actsLikeCacheable(baseUrl, options, done) {
    makeDuplicateRequests(baseUrl, options, function(error, result) {
      if(result.firstResponse.headers['age']) {
        result.firstResponse.headers['age'].should.eql('0');
      } else {
        should.not.exist(result.firstResponse.headers['age']);
      }

      should.exist(result.secondResponse.headers['age']);

      result.firstBody.length.should.be.greaterThan(0);
      result.firstBody.should.eql(result.secondBody);

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
        response.statusCode.should.eql(200);
        callback(null, body);
      });
    }, function(error, bodies) {
      should.exist(global.backendCallCounts[id]);
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
      should.exist(global.backendCallCounts[id]);
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
    ['GET'].forEach(function(method) {
      it('allows caching for ' + method + ' requests', function(done) {
        var options = _.merge({}, this.options, { method: method });
        actsLikeCacheable('http://localhost:9080/cacheable-cache-control-max-age/', options, done);
      });
    });

    ['HEAD'].forEach(function(method) {
      it('allows caching for ' + method + ' requests', function(done) {
        var options = _.merge({}, this.options, { method: method });
        makeDuplicateRequests('http://localhost:9080/cacheable-cache-control-max-age/', options, function(error, result) {
          if(result.firstResponse.headers['age']) {
            result.firstResponse.headers['age'].should.eql('0');
          } else {
            should.not.exist(result.firstResponse.headers['age']);
          }

          should.exist(result.secondResponse.headers['age']);

          result.firstResponse.headers['x-unique-output'].length.should.be.greaterThan(0);
          result.firstResponse.headers['x-unique-output'].should.eql(result.secondResponse.headers['x-unique-output']);

          done(error, result);
        });
      });

      it('returns a cached ' + method + ' request when a GET request is made first', function(done) {
        var options = _.merge({}, this.options, {
          method: 'GET',
          secondCallOverrides: {
            method: method,
          },
        });

        makeDuplicateRequests('http://localhost:9080/cacheable-cache-control-max-age/', options, function(error, result) {
          if(result.firstResponse.headers['age']) {
            result.firstResponse.headers['age'].should.eql('0');
          } else {
            should.not.exist(result.firstResponse.headers['age']);
          }

          should.exist(result.secondResponse.headers['age']);

          result.firstResponse.headers['x-unique-output'].length.should.be.greaterThan(0);
          result.firstResponse.headers['x-unique-output'].should.eql(result.secondResponse.headers['x-unique-output']);

          done(error, result);
        });
      });
    });
  });

  describe('non-cacheable http methods', function() {
    ['POST', 'PUT', 'PATCH', 'OPTIONS', 'DELETE'].forEach(function(method) {
      it('does not allow caching for ' + method + ' requests', function(done) {
        var options = _.merge({}, this.options, { method: method });
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

  it('does not cache responses that set cookies', function(done) {
    actsLikeNotCacheable('http://localhost:9080/cacheable-set-cookie/', this.options, done);
  });

  it('does not cache responses that expires at 0', function(done) {
    var options = _.merge({}, this.options, { secondCallSleep: 1000 });
    actsLikeNotCacheable('http://localhost:9080/cacheable-expires-0/', options, done);
  });

  it('does not cache responses that expires in the past', function(done) {
    var options = _.merge({}, this.options, { secondCallSleep: 1000 });
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
    // Normalize the Accept-Encoding header to maximize caching:
    // https://docs.trafficserver.apache.org/en/latest/reference/configuration/records.config.en.html?highlight=gzip#proxy-config-http-normalize-ae-gzip 
    describe('accept-encoding normalization', function() {
      it('leaves accept-encoding equalling "gzip"', function(done) {
        var options = _.merge({}, this.options, {
          gzip: true,
          headers: {
            'Accept-Encoding': 'gzip',
          },
        });

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.headers['accept-encoding'].should.eql('gzip');
          done();
        });
      });

      it('changes accept-encoding containing "gzip" to just "gzip"', function(done) {
        var options = _.merge({}, this.options, {
          gzip: true,
          headers: {
            'Accept-Encoding': 'gzip, deflate, compress',
          },
        });

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.headers['accept-encoding'].should.eql('gzip');
          done();
        });
      });

      it('removes accept-encoding not containing "gzip"', function(done) {
        var options = _.merge({}, this.options, {
          gzip: true,
          headers: {
            'Accept-Encoding': 'deflate, compress',
          },
        });

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          should.not.exist(data.headers['accept-encoding']);
          done();
        });
      });

      it('removes accept-encoding containing "gzip", but not as a standalone entry ("gzipp")', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Accept-Encoding': 'gzipp',
          },
        });

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          should.not.exist(data.headers['accept-encoding']);
          done();
        });
      });

      it('removes accept-encoding if gzip is q=0', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Accept-Encoding': 'gzip;q=0',
          },
        });

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          should.not.exist(data.headers['accept-encoding']);
          done();
        });
      });
    });

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

    describe('optimized gzip behavior', function() {
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
