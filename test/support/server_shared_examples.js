require('../test_helper');

var _ = require('underscore');

global.shared = {
  buildRequestOptions: function(path, apiKey, options) {
    return _.extend({
        url: 'http://localhost:9333' + path,
        qs: { api_key: apiKey },
      }, options);
  },

  runServer: function(options) {
    beforeEach(function(done) {
      Factory.create('api_user', function(user) {
        this.apiKey = user.api_key;
        done();
      }.bind(this));
    });

    beforeEach(function(done) {
      var serverOptions = _.extend({
        port: 9333,
        backend: "localhost:9444",
        mongo: 'mongodb://127.0.0.1:27017/api_umbrella_test',
        haproxy_log_listener: {
          port: 9334
        },
        rate_limits: [],
      }, options);

      backendCalled = false;
      this.gatekeeper = gatekeeper.startNonForked(serverOptions, function() {
        done();
      });
    });

    afterEach(function(done) {
      this.gatekeeper.closeNonForked(function() {
        done();
      });
    });
  },

  itBehavesLikeGatekeeperBlocked: function(path, statusCode, message, options) {
    it("doesn't call the target app", function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function(error, response, body) {
        backendCalled.should.eql(false);
        done();
      });
    });

    it('returns a blocked status code and message', function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function(error, response, body) {
        response.statusCode.should.eql(statusCode);
        body.should.include(message);
        done();
      });
    });
  },

  itBehavesLikeGatekeeperAllowed: function(path, message, options) {
    it("calls the target app", function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function(error, response, body) {
        backendCalled.should.eql(true);
        done();
      });
    });

    it("returns a successful response", function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function(error, response, body) {
        response.statusCode.should.eql(200);
        done();
      });
    });
  },
}
