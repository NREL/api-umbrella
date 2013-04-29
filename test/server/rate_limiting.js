require('../test_helper');

var _ = require('underscore'),
    async = require('async'),
    timekeeper = require('timekeeper');

describe('ApiUmbrellaGatekeper', function() {
  describe('rate limiting', function() {
    describe('single hourly limit', function() {
      shared.runServer({
        proxy: {
          rate_limits: [
            {
              duration: 60 * 60 * 1000, // 1 hour
              accuracy: 1 * 60 * 1000, // 1 minute
              limit_by: 'api_key',
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
            body.should.eql("Hello World");
            asyncCallback(null);
          });
        }.bind(this), function() {
          done();
        });
      });

      it('rejects requests after the hourly limit has been exceeded', function(done) {
        timekeeper.freeze(new Date(2013, 1, 1, 1, 27, 0));
        async.times(10, function(index, asyncCallback) {
          request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
            asyncCallback(null);
          });
        }.bind(this), function() {
          timekeeper.freeze(new Date(2013, 1, 1, 2, 26, 59));
          request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
            response.statusCode.should.eql(429);
            body.should.include("over_rate_limit");

            timekeeper.reset();
            done();
          });
        }.bind(this));
      });

      it('allows requests again in the next hour after the rate limit has been exceeded', function(done) {
        timekeeper.freeze(new Date(2013, 1, 1, 1, 27, 0));
        async.times(11, function(index, asyncCallback) {
          request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
            asyncCallback(null);
          });
        }.bind(this), function() {
          timekeeper.freeze(new Date(2013, 1, 1, 2, 27, 0));
          request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
            response.statusCode.should.eql(200);
            body.should.eql("Hello World");

            timekeeper.reset();
            done();
          });
        }.bind(this));
      });
    });

    describe('multiple limits', function() {
      shared.runServer({
        proxy: {
          rate_limits: [
            {
              duration: 10 * 1000, // 10 second
              accuracy: 1000, // 1 second
              limit_by: 'api_key',
              limit: 3,
            }, {
              duration: 60 * 60 * 1000, // 1 hour
              accuracy: 1 * 60 * 1000, // 1 minute
              limit_by: 'api_key',
              limit: 10,
              distributed: true,
            }
          ]
        }
      });

      it('does not count excess queries in the smaller time window against the larger time window', function(done) {
        timekeeper.freeze(new Date(2013, 1, 1, 1, 27, 43));
        async.times(15, function(index, asyncCallback) {
          request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
            asyncCallback(null);
          });
        }.bind(this), function() {
          timekeeper.freeze(new Date(2013, 1, 1, 1, 27, 53));

          request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
            response.statusCode.should.eql(200);
            body.should.eql("Hello World");

            timekeeper.reset();
            done();
          });
        }.bind(this));
      });
    });
  });
});
