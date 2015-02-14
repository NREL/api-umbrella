'use strict';

require('../test_helper');

var _ = require('lodash'),
    csv = require('csv'),
    execFile = require('child_process').execFile,
    Factory = require('factory-lady'),
    fs = require('fs'),
    ippp = require('ipplusplus'),
    mergeOverwriteArrays = require('object-extend'),
    path = require('path'),
    request = require('request'),
    uuid = require('node-uuid'),
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
    before(function setupConfig(done) {
      var paths = [
        path.resolve(__dirname, '../../config/default.yml'),
        path.resolve(__dirname, '../config/test.yml'),
      ];

      var config = {};
      paths.forEach(function(path) {
        var data = fs.readFileSync(path);
        var values = yaml.safeLoad(data.toString());

        mergeOverwriteArrays(config, values);
      });

      if(configOverrides) {
        mergeOverwriteArrays(config, configOverrides);
      }

      if(config.apis) {
        config.apis.forEach(function(api) {
          if(!api._id) {
            api._id = uuid.v4();
          }

          if(!api.servers) {
            api.servers = [
              {
                host: '127.0.0.1',
                port: 9444,
              }
            ];
          }
        });
      }

      // Dump as YAML, with nulls being treated as real YAML nulls, rather than
      // the string "null" (which is js-yaml's default).
      fs.writeFileSync('/tmp/runtime_config_test.yml', yaml.safeDump(config, { styles: { '!!null': 'canonical' } }));
      done();
    });

    before(function reloadNginx(done) {
      execFile('pkill', ['-HUP', '-f', 'nginx: master'], function() {
        setTimeout(done, 1500);
      });
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

    beforeEach(function resetBackendCalled(done) {
      backendCalled = false;
      done();
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
