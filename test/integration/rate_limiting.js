'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    Factory = require('factory-lady'),
    request = require('request');

describe('rate limiting', function() {
  beforeEach(function(done) {
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

  describe('global router limits', function() {
    describe('ip connection limits', function() {
      beforeEach(function() {
        this.options = _.merge({}, this.options, {
          headers: {
            // Disable router rate limits (requests per second), since we're
            // only wanting to test IP connection limits here.
            'X-Disable-Router-Rate-Limits': 'yes',
          },
        });
      });

      it('allows up to 50 concurrent connections from a single IP', function(done) {
        this.timeout(7000);

        async.times(50, function(index, callback) {
          request.get('http://localhost:9080/delay/2000', this.options, function(error, response) {
            callback(error, response.statusCode);
          });
        }.bind(this), function(error, responseCodes) {
          should.not.exist(error);
          responseCodes.length.should.eql(50);
          _.uniq(responseCodes).should.eql([200]);
          done();
        });
      });

      it('returns 429 over rate limit error when concurrent connections from a single IP exceeds 50', function(done) {
        this.timeout(7000);

        async.times(51, function(index, callback) {
          request.get('http://localhost:9080/delay/2000', this.options, function(error, response) {
            callback(error, response.statusCode);
          });
        }.bind(this), function(error, responseCodes) {
          should.not.exist(error);
          var successes = _.filter(responseCodes, function(code) { return code === 200; });
          var overLimits = _.filter(responseCodes, function(code) { return code === 429; });

          responseCodes.length.should.eql(51);
          successes.length.should.eql(50);
          overLimits.length.should.eql(1);

          done();
        });
      });

      it('can bypass the connection limits in the test environment with the X-Disable-Router-Connection-Limits header', function(done) {
        this.timeout(30000);

        var options = _.merge({}, this.options, {
          headers: {
            'X-Disable-Router-Connection-Limits': 'yes',
          },
        });

        async.times(110, function(index, callback) {
          request.get('http://localhost:9080/delay/5000', options, function(error, response) {
            callback(error, response.statusCode);
          });
        }.bind(this), function(error, responseCodes) {
          should.not.exist(error);
          responseCodes.length.should.eql(110);
          _.uniq(responseCodes).should.eql([200]);
          done();
        });
      });
    });

    describe('rate limits (requests per second)', function() {
      beforeEach(function() {
        this.options = _.merge({}, this.options, {
          headers: {
            // Disable concurrent connection limits, since we're only wanting
            // to test request per second rate limits here.
            'X-Disable-Router-Connection-Limits': 'yes',
          },
        });
      });

      it('allows up to 100 requests per second from a single IP', function(done) {
        this.timeout(7000);

        // Delay to allow the per-second rate limit to clear.
        setTimeout(function() {
          async.times(100, function(index, callback) {
            request.get('http://localhost:9080/info/', this.options, function(error, response) {
              callback(error, response.statusCode);
            });
          }.bind(this), function(error, responseCodes) {
            should.not.exist(error);
            responseCodes.length.should.eql(100);
            _.uniq(responseCodes).should.eql([200]);
            done();
          });
        }.bind(this), 1501);
      });

      it('allows a burst of 100 additional requests (200 total requests) from a single IP', function(done) {
        this.timeout(7000);

        // Delay to allow the per-second rate limit to clear.
        setTimeout(function() {
          async.times(200, function(index, callback) {
            request.get('http://localhost:9080/info/', this.options, function(error, response) {
              callback(error, response.statusCode);
            });
          }.bind(this), function(error, responseCodes) {
            should.not.exist(error);
            responseCodes.length.should.eql(200);
            _.uniq(responseCodes).should.eql([200]);
            done();
          });
        }.bind(this), 1501);
      });

      it('returns 429 over rate limit error when the requests per second exceeds the rate limit plus burst', function(done) {
        this.timeout(7000);

        // Delay to allow the per-second rate limit to clear.
        setTimeout(function() {
          async.times(250, function(index, callback) {
            request.get('http://localhost:9080/info/', this.options, function(error, response) {
              callback(error, response.statusCode);
            });
          }.bind(this), function(error, responseCodes) {
            should.not.exist(error);
            var successes = _.filter(responseCodes, function(code) { return code === 200; });
            var overLimits = _.filter(responseCodes, function(code) { return code === 429; });

            responseCodes.length.should.eql(250);

            // The burst handling seems a bit fuzzy (or we're not making
            // requests fast enough), so it's not a hard 200 requests where we
            // start getting 429 errors. So instead, just make sure we
            // generally start returning 429 errors for some requests once
            // we're over 200 requests.
            successes.length.should.be.gte(200);
            successes.length.should.be.lte(225);
            overLimits.length.should.be.gte(1);
            overLimits.length.should.be.lte(50);
            (successes.length + overLimits.length).should.eql(250);

            done();
          });
        }.bind(this), 1501);
      });

      it('can bypass the connection limits in the test environment with the X-Disable-Router-Connection-Limits header', function(done) {
        this.timeout(7000);

        var options = _.merge({}, this.options, {
          headers: {
            'X-Disable-Router-Rate-Limits': 'yes',
          },
        });

        // Delay to allow the per-second rate limit to clear.
        setTimeout(function() {
          async.times(310, function(index, callback) {
            request.get('http://localhost:9080/info/', options, function(error, response) {
              callback(error, response.statusCode);
            });
          }.bind(this), function(error, responseCodes) {
            should.not.exist(error);
            responseCodes.length.should.eql(310);
            _.uniq(responseCodes).should.eql([200]);
            done();
          });
        }.bind(this), 1501);
      });
    });
  });

  describe('gatekeeper limits', function() {
  });
});
