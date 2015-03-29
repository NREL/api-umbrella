'use strict';

require('../test_helper');

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    csv = require('csv'),
    Factory = require('factory-lady'),
    fs = require('fs'),
    ippp = require('ipplusplus'),
    path = require('path'),
    request = require('request'),
    xml2js = require('xml2js'),
    yaml = require('js-yaml');

global.backendCalled = false;
global.autoIncrementingIpAddress = '10.0.0.0';

_.merge(global.shared, {
  buildRequestOptions: function(path, apiKey, options) {
    return _.extend({
        url: 'http://localhost:9333' + path,
        qs: { api_key: apiKey },
      }, options);
  },

  runServer: function(configOverrides) {
    beforeEach(function startConfigLoader(done) {
      this.timeout(5000);
      var overridesPath = path.resolve(__dirname, '../config/overrides.yml');
      fs.writeFileSync(overridesPath, yaml.dump(configOverrides || {}));

      apiUmbrellaConfig.loader({
        paths: [
          path.resolve(__dirname, '../../config/default.yml'),
          path.resolve(__dirname, '../config/test.yml'),
        ],
        overrides: configOverrides,
      }, function(error, loader) {
        this.loader = loader;
        done(error);
      }.bind(this));
    });

    beforeEach(function createDefaultApiUser(done) {
      global.autoIncrementingIpAddress = ippp.next(global.autoIncrementingIpAddress);
      this.ipAddress = global.autoIncrementingIpAddress;

      Factory.create('api_user', function(user) {
        this.user = user;
        this.apiKey = user.api_key;
        this.options = {
          headers: {
            'X-Api-Key': this.apiKey,
          }
        };
        done();
      }.bind(this));
    });

    beforeEach(function startGatekeeper(done) {
      backendCalled = false;

      this.gatekeeper = gatekeeper.start({
        config: this.loader.runtimeFile,
      }, done);
    });

    afterEach(function stopConfigLoader(done) {
      if(this.loader) {
        this.loader.close(done);
      }
    });

    afterEach(function stopGatekeeper(done) {
      if(this.gatekeeper) {
        this.gatekeeper.close(done);
      }
    });
  },

  itBehavesLikeGatekeeperBlocked: function(path, statusCode, errorCode, options) {
    it('doesn\'t call the target app', function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function(error) {
        should.not.exist(error);
        backendCalled.should.eql(false);
        done();
      });
    });

    it('returns a ' + statusCode + ' status code', function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(statusCode);
        done();
      });
    });

    it('allows errors to be accessed from any origin via CORS', function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function(error, response) {
        should.not.exist(error);
        response.headers['access-control-allow-origin'].should.eql('*');
        done();
      });
    });

    if(errorCode) {
      it('returns a blocked error code', function(done) {
        request(shared.buildRequestOptions(path, this.apiKey, options), function(error, response, body) {
          should.not.exist(error);
          body.should.include(errorCode);
          done();
        });
      });

      describe('formatted error responses', function() {
        it('returns a JSON error response', function(done) {
          request(shared.buildRequestOptions(path + '.json', this.apiKey, options), function(error, response, body) {
            should.not.exist(error);
            var data = JSON.parse(body);
            data.error.code.should.eql(errorCode);
            done();
          });
        });

        it('returns an XML error response', function(done) {
          request(shared.buildRequestOptions(path + '.xml', this.apiKey, options), function(error, response, body) {
            should.not.exist(error);
            xml2js.parseString(body, function(error, data) {
              data.response.error[0].code[0].should.eql(errorCode);
              done();
            });
          });
        });

        it('returns CSV error response', function(done) {
          request(shared.buildRequestOptions(path + '.csv', this.apiKey, options), function(error, response, body) {
            should.not.exist(error);
            csv().from.string(body).to.array(function(data) {
              data[1][0].should.eql(errorCode);
              done();
            });
          });
        });
      });
    }
  },

  itBehavesLikeGatekeeperAllowed: function(path, options) {
    it('calls the target app', function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function(error) {
        should.not.exist(error);
        backendCalled.should.eql(true);
        done();
      });
    });

    it('returns a successful response', function(done) {
      request(shared.buildRequestOptions(path, this.apiKey, options), function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        done();
      });
    });
  },
});
