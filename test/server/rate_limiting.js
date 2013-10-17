'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    ippp = require('ipplusplus'),
    timekeeper = require('timekeeper');

describe('ApiUmbrellaGatekeper', function() {
  describe('rate limiting', function() {
    function headers(defaults, overrides) {
      var headersObj = _.extend(defaults, overrides);

      for(var header in headersObj) {
        if(headersObj[header] === null || headersObj[header] === undefined) {
          delete headersObj[header];
        }
      }

      return headersObj;
    }

    function itBehavesLikeApiKeyRateLimits(path, limit, headerOverrides) {
      it('allows up to the limit of requests and then begins rejecting requests', function(done) {
        var options = {
          headers: headers({
            'X-Api-Key': this.apiKey,
          }, headerOverrides),
        };

        async.times(limit, function(index, asyncCallback) {
          request.get('http://localhost:9333' + path, options, function(error, response) {
            response.statusCode.should.eql(200);
            asyncCallback(null);
          });
        }.bind(this), function() {
          request.get('http://localhost:9333' + path, options, function(error, response) {
            response.statusCode.should.eql(429);
            done();
          });
        }.bind(this));
      });

      it('counts api keys differently', function(done) {
        var options = {
          headers: headers({
            'X-Api-Key': this.apiKey,
          }, headerOverrides),
        };

        async.times(limit, function(index, asyncCallback) {
          request.get('http://localhost:9333' + path, options, function(error, response) {
            response.statusCode.should.eql(200);
            asyncCallback(null);
          });
        }.bind(this), function() {
          Factory.create('api_user', function(user) {
            options.headers['X-Api-Key'] = user.api_key;

            request.get('http://localhost:9333' + path, options, function(error, response) {
              response.statusCode.should.eql(200);
              done();
            });
          });
        });
      });
    }

    function itBehavesLikeIpRateLimits(path, limit, headerOverrides) {
      it('allows up to the limit of requests and then begins rejecting requests', function(done) {
        var options = {
          headers: headers({
            'X-Forwarded-For': this.ipAddress,
            'X-Api-Key': this.apiKey,
          }, headerOverrides),
        };

        async.times(limit, function(index, asyncCallback) {
          request.get('http://localhost:9333' + path, options, function(error, response) {
            response.statusCode.should.eql(200);
            asyncCallback(null);
          });
        }, function() {
          request.get('http://localhost:9333' + path, options, function(error, response) {
            response.statusCode.should.eql(429);
            done();
          });
        });
      });

      it('counts ip addresses differently', function(done) {
        var options = {
          headers: headers({
            'X-Forwarded-For': this.ipAddress,
            'X-Api-Key': this.apiKey,
          }, headerOverrides),
        };

        async.times(limit, function(index, asyncCallback) {
          request.get('http://localhost:9333' + path, options, function(error, response) {
            response.statusCode.should.eql(200);
            asyncCallback(null);
          });
        }, function() {
          this.ipAddress = ippp.next(this.ipAddress);
          options.headers['X-Forwarded-For'] = this.ipAddress;

          request.get('http://localhost:9333' + path, options, function(error, response) {
            response.statusCode.should.eql(200);
            done();
          });
        }.bind(this));
      });
    }

    describe('single hourly limit', function() {
      shared.runServer({
        apiSettings: {
          rate_limits: [
            {
              duration: 60 * 60 * 1000, // 1 hour
              accuracy: 1 * 60 * 1000, // 1 minute
              limit_by: 'apiKey',
              limit: 10,
              distributed: true,
            }
          ]
        }
      });

      it('allows up to the hourly limit of requests', function(done) {
        async.times(10, function(index, asyncCallback) {
          request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
            response.statusCode.should.eql(200);
            body.should.eql('Hello World');
            asyncCallback(null);
          });
        }.bind(this), function() {
          done();
        });
      });

      it('rejects requests after the hourly limit has been exceeded', function(done) {
        timekeeper.freeze(new Date(2013, 1, 1, 1, 27, 0));
        async.times(10, function(index, asyncCallback) {
          request.get('http://localhost:9333/hello.xml?api_key=' + this.apiKey, function() {
            asyncCallback(null);
          });
        }.bind(this), function() {
          timekeeper.freeze(new Date(2013, 1, 1, 2, 26, 59));
          request.get('http://localhost:9333/hello.xml?api_key=' + this.apiKey, function(error, response, body) {
            response.statusCode.should.eql(429);
            body.should.include('<code>OVER_RATE_LIMIT</code>');

            timekeeper.reset();
            done();
          });
        }.bind(this));
      });

      it('allows requests again in the next hour after the rate limit has been exceeded', function(done) {
        timekeeper.freeze(new Date(2013, 1, 1, 1, 27, 0));
        async.times(11, function(index, asyncCallback) {
          request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function() {
            asyncCallback(null);
          });
        }.bind(this), function() {
          timekeeper.freeze(new Date(2013, 1, 1, 2, 27, 0));
          request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
            response.statusCode.should.eql(200);
            body.should.eql('Hello World');

            timekeeper.reset();
            done();
          });
        }.bind(this));
      });
    });

    describe('multiple limits', function() {
      shared.runServer({
        apiSettings: {
          rate_limits: [
            {
              duration: 10 * 1000, // 10 second
              accuracy: 1000, // 1 second
              limit_by: 'apiKey',
              limit: 3,
            }, {
              duration: 60 * 60 * 1000, // 1 hour
              accuracy: 1 * 60 * 1000, // 1 minute
              limit_by: 'apiKey',
              limit: 10,
              distributed: true,
            }
          ]
        }
      });

      it('does not count excess queries in the smaller time window against the larger time window', function(done) {
        timekeeper.freeze(new Date(2013, 1, 1, 1, 27, 43));
        async.times(15, function(index, asyncCallback) {
          request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function() {
            asyncCallback(null);
          });
        }.bind(this), function() {
          timekeeper.freeze(new Date(2013, 1, 1, 1, 27, 53));

          request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
            response.statusCode.should.eql(200);
            body.should.eql('Hello World');

            timekeeper.reset();
            done();
          });
        }.bind(this));
      });
    });

    describe('ip based rate limits', function() {
      shared.runServer({
        apiSettings: {
          rate_limits: [
            {
              duration: 60 * 60 * 1000, // 1 hour
              accuracy: 1 * 60 * 1000, // 1 minute
              limit_by: 'ip',
              limit: 5,
              distributed: true,
            }
          ]
        },
      });

      itBehavesLikeIpRateLimits('/hello', 5);
    });

    describe('api key limits but no api key required', function() {
      shared.runServer({
        apiSettings: {
          rate_limits: [
            {
              duration: 60 * 60 * 1000, // 1 hour
              accuracy: 1 * 60 * 1000, // 1 minute
              limit_by: 'apiKey',
              limit: 5,
              distributed: true,
            }
          ]
        },
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
            },
          },
        ],
      });

      describe('api key not required but still given', function() {
        itBehavesLikeApiKeyRateLimits('/info/no-keys', 5);
      });

      describe('api key ommitted', function() {
        itBehavesLikeIpRateLimits('/info/no-keys', 5, {
          'X-Api-Key': undefined,
        });
      });
    });
  });
});
