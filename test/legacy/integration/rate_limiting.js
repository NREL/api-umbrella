'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    Factory = require('factory-lady'),
    ippp = require('ipplusplus'),
    request = require('request');

describe('rate limiting', function() {
  shared.runServer();

  describe('global router limits', function() {
    describe('defaults', function() {
      shared.runServer();

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

      it('does not apply any global limits by default', function(done) {
        this.timeout(10000);

        async.times(400, function(index, callback) {
          request.get('http://localhost:9080/info/', this.options, function(error, response) {
            callback(error, response.statusCode);
          });
        }.bind(this), function(error, responseCodes) {
          should.not.exist(error);
          responseCodes.length.should.eql(400);
          _.uniq(responseCodes).should.eql([200]);
          done();
        });
      });
    });

    describe('ip connection limits', function() {
      shared.runServer({
        router: {
          global_rate_limits: {
            ip_connections: 20
          },
        },
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

      it('allows up to a configurable number of concurrent connections from a single IP', function(done) {
        this.timeout(20000);

        async.times(20, function(index, callback) {
          request.get('http://localhost:9080/delay/2000', this.options, function(error, response) {
            callback(error, response.statusCode);
          });
        }.bind(this), function(error, responseCodes) {
          should.not.exist(error);
          responseCodes.length.should.eql(20);
          _.uniq(responseCodes).should.eql([200]);
          done();
        });
      });

      it('returns 429 over rate limit error when concurrent connections from a single IP exceeds the configured number', function(done) {
        this.timeout(20000);

        async.times(21, function(index, callback) {
          request.get('http://localhost:9080/delay/2000', this.options, function(error, response) {
            callback(error, response.statusCode);
          });
        }.bind(this), function(error, responseCodes) {
          should.not.exist(error);
          var successes = _.filter(responseCodes, function(code) { return code === 200; });
          var overLimits = _.filter(responseCodes, function(code) { return code === 429; });

          responseCodes.length.should.eql(21);
          successes.length.should.eql(20);
          overLimits.length.should.eql(1);

          done();
        });
      });
    });

    describe('rate limits (requests per second)', function() {
      shared.runServer({
        router: {
          global_rate_limits: {
            ip_rate: '10r/s',
            ip_burst: 20,
          },
        },
      });

      beforeEach(function createUser(done) {
        global.autoIncrementingIpAddress = ippp.next(global.autoIncrementingIpAddress);

        Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
          this.apiKey = user.api_key;
          this.options = {
            headers: {
              'X-Api-Key': this.apiKey,

              // Perform each batch of tests as though its from a unique IP
              // address so requests from different tests don't interfere with
              // each other.
              'X-Forwarded-For': global.autoIncrementingIpAddress,
            },
            agentOptions: {
              maxSockets: 500,
            },
          };

          done();
        }.bind(this));
      });

      it('allows up to a configurable number of requests per second from a single IP', function(done) {
        this.timeout(7000);

        async.times(10, function(index, callback) {
          request.get('http://localhost:9080/info/', this.options, function(error, response) {
            callback(error, response.statusCode);
          });
        }.bind(this), function(error, responseCodes) {
          should.not.exist(error);
          responseCodes.length.should.eql(10);
          _.uniq(responseCodes).should.eql([200]);
          done();
        });
      });

      it('allows a burst of additional requests from a single IP', function(done) {
        this.timeout(7000);

        async.times(20, function(index, callback) {
          request.get('http://localhost:9080/info/', this.options, function(error, response) {
            callback(error, response.statusCode);
          });
        }.bind(this), function(error, responseCodes) {
          should.not.exist(error);
          responseCodes.length.should.eql(20);
          _.uniq(responseCodes).should.eql([200]);
          done();
        });
      });

      it('returns 429 over rate limit error when the requests per second exceeds the rate limit plus burst', function(done) {
        this.timeout(7000);

        async.times(40, function(index, callback) {
          request.get('http://localhost:9080/info/', this.options, function(error, response) {
            callback(error, response.statusCode);
          });
        }.bind(this), function(error, responseCodes) {
          should.not.exist(error);
          var successes = _.filter(responseCodes, function(code) { return code === 200; });
          var overLimits = _.filter(responseCodes, function(code) { return code === 429; });

          responseCodes.length.should.eql(40);

          // The rate limiting and burst handling is a bit fuzzy since we
          // don't know exactly when the initial rate limit has been exceeded
          // (since nginx limits aren't based on hard counts, but instead the
          // average rate of requests, and we also don't know how fast the
          // nodejs tests are actually making requests). Since we don't know
          // when the burst kicks in, just make sure we generally start
          // returning over rate limit errors.
          successes.length.should.be.gte(20);
          successes.length.should.be.lte(34);
          overLimits.length.should.be.gte(1);
          (successes.length + overLimits.length).should.eql(40);

          done();
        });
      });
    });
  });

  describe('gatekeeper limits', function() {
  });
});
