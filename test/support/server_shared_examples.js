'use strict';

require('../test_helper');

var _ = require('lodash'),
    config = require('../../lib/config'),
    csv = require('csv'),
    ippp = require('ipplusplus'),
    xml2js = require('xml2js');

global.backendCalled = false;

_.merge(global.shared, {
  buildRequestOptions: function(path, apiKey, options) {
    return _.extend({
        url: 'http://localhost:9333' + path,
        qs: { api_key: apiKey },
      }, options);
  },

  runServer: function(configOverrides) {
    beforeEach(function(done) {
      if(!this.ipAddress) {
        this.ipAddress = '10.0.0.1';
      } else {
        this.ipAddress = ippp.next(this.ipAddress);
      }

      Factory.create('api_user', function(user) {
        this.user = user;
        this.apiKey = user.api_key;
        done();
      }.bind(this));
    });

    beforeEach(function(done) {
      backendCalled = false;

      config.reset();

      if(configOverrides) {
        config.updateRuntime({ apiUmbrella: configOverrides });
      }

      this.gatekeeper = gatekeeper.start({}, done);
    });

    afterEach(function(done) {
      this.gatekeeper.close(done);
    });
  },

  itBehavesLikeGatekeeperBlocked: function(path, statusCode, errorCode, options) {
    it('doesn\'t call the target app', function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function() {
        backendCalled.should.eql(false);
        done();
      });
    });

    it('returns a blocked status code and error code', function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function(error, response, body) {
        response.statusCode.should.eql(statusCode);
        body.should.include(errorCode);
        done();
      });
    });

    it('allows errors to be accessed from any origin via CORS', function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function(error, response) {
        response.headers['access-control-allow-origin'].should.eql('*');
        done();
      });
    });

    describe('formatted error responses', function() {
      it('returns a JSON error response', function(done) {
        request(shared.buildRequestOptions(path + '.json', this.apiKey, options), function(error, response, body) {
          var data = JSON.parse(body);
          data.error.code.should.eql(errorCode);
          done();
        });
      });

      it('returns an XML error response', function(done) {
        request(shared.buildRequestOptions(path + '.xml', this.apiKey, options), function(error, response, body) {
          xml2js.parseString(body, function(error, data) {
            data.response.error[0].code[0].should.eql(errorCode);
            done();
          });
        });
      });

      it('returns CSV error response', function(done) {
        request(shared.buildRequestOptions(path + '.csv', this.apiKey, options), function(error, response, body) {
          csv().from.string(body).to.array(function(data) {
            data[1][0].should.eql(errorCode);
            done();
          });
        });
      });
    });
  },

  itBehavesLikeGatekeeperAllowed: function(path, options) {
    it('calls the target app', function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function() {
        backendCalled.should.eql(true);
        done();
      });
    });

    it('returns a successful response', function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function(error, response) {
        response.statusCode.should.eql(200);
        done();
      });
    });
  },
});
