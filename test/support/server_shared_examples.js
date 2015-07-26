'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    csv = require('csv'),
    Factory = require('factory-lady'),
    fs = require('fs'),
    fsExtra = require('fs-extra'),
    ippp = require('ipplusplus'),
    mergeOverwriteArrays = require('object-extend'),
    mongoose = require('mongoose'),
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
        url: 'http://localhost:9080' + path,
        qs: { api_key: apiKey },
      }, options);
  },

  setConfigOverrides: function setConfigOverrides(newConfig, callback) {
    global.currentConfigOverrides = newConfig;

    var testConfigPath = path.resolve(__dirname, '../config/test.yml');
    var overridesConfigPath = path.resolve(__dirname, '../config/.overrides.yml');

    var data = fs.readFileSync(testConfigPath);
    var config = yaml.safeLoad(data.toString());
    mergeOverwriteArrays(config, newConfig);

    // Generate a unique ID for this config, so we can detect when it's been
    // loaded.
    config.config_id = uuid.v4();
    global.currentConfigId = config.config_id;

    // Dump as YAML, with nulls being treated as real YAML nulls, rather than
    // the string "null" (which is js-yaml's default).
    fs.writeFileSync(overridesConfigPath, yaml.safeDump(config, { styles: { '!!null': 'canonical' } }));

    shared.runCommand('reload', callback);
  },

  revertConfigOverrides: function revertConfigOverrides(callback) {
    global.currentConfigId = undefined;
    var testConfigPath = path.resolve(__dirname, '../config/test.yml');
    var overridesConfigPath = path.resolve(__dirname, '../config/.overrides.yml');
    fsExtra.copySync(testConfigPath, overridesConfigPath);
    shared.runCommand('reload', callback);
  },

  setRuntimeConfigOverrides: function setRuntimeConfigOverrides(newRuntimeConfig, callback) {
    global.currentRuntimeConfigOverrides = newRuntimeConfig;

    if(newRuntimeConfig.apis) {
      newRuntimeConfig.apis.forEach(function(api) {
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

    mongoose.testConnection.model('RouterConfigVersion').remove({}, function(error) {
      should.not.exist(error);

      Factory.create('config_version', {
        config: newRuntimeConfig,
      }, function(record) {
        global.currentRuntimeConfigVersion = record.version.getTime();
        callback();
      });
    });
  },

  revertRuntimeConfigOverrides: function revertRuntimeConfigOverrides(callback) {
    var error;
    var attempts = 0;

    // Retry the removal cleanup a few times to help when testing mongodb
    // replicaset changes when the javascript client might not have picked up
    // the new primary mongodb server in the test cluster (when testing forced
    // replicaset primary changes).
    async.doUntil(function(callback) {
      mongoose.testConnection.model('RouterConfigVersion').remove({}, function(e) {
        error = e;
        attempts++;
        if(error) {
          setTimeout(callback, 500);
        } else {
          callback();
        }
      });
    }, function() {
      return !error || attempts > 20;
    }, function() {
      should.not.exist(error);

      Factory.create('config_version', {
        config: {},
      }, function(record) {
        global.currentRuntimeConfigVersion = record.version.getTime();
        callback();
      });
    });
  },

  waitForConfig: function waitForConfig(callback) {
    var configLoaded = false;
    var timedOut = false;
    var timeout = setTimeout(function() { timedOut = true; }, 4800);
    var data;

    async.until(function() {
      return configLoaded || timedOut;
    }, function(callback) {
      request.get('http://127.0.0.1:9080/api-umbrella/v1/state?' + Math.random(), function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);

        data = JSON.parse(body);
        if(data['runtime_config_version'] === global.currentRuntimeConfigVersion && data['config_id'] === global.currentConfigId) {
          configLoaded = true;
          if(timeout) {
            clearTimeout(timeout);
            timeout = null;
          }

          return callback();
        }

        setTimeout(callback, 10);
      });
    }, function() {
      if(timeout) {
        clearTimeout(timeout);
        timeout = null;
      }

      if(!configLoaded) {
        callback('configuration did not load in the expected amount of time (global.currentRuntimeConfigVersion: ' + global.currentRuntimeConfigVersion + ' global.currentConfigId: ' + global.currentConfigId + ' data: ' + JSON.stringify(data));
      } else {
        callback();
      }
    });
  },

  runServer: function(configOverrides) {
    configOverrides = configOverrides || {};
    if(!configOverrides.apis) {
      configOverrides.apis = [
        {
          _id: 'example',
          frontend_host: 'localhost',
          backend_host: 'localhost',
          servers: [
            {
              host: '127.0.0.1',
              port: 9444,
            },
          ],
          url_matches: [
            {
              frontend_prefix: '/',
              backend_prefix: '/',
            },
          ],
        },
      ];
    }

    var runtimeKeys = ['apis', 'website_backends'];
    var newConfig = _.omit(configOverrides, runtimeKeys);
    var newRuntimeConfig = _.pick(configOverrides, runtimeKeys);

    if(!_.isEmpty(newConfig)) {
      before(function setupConfig(done) {
        shared.setConfigOverrides(newConfig, done);
      });

      after(function revertConfig(done) {
        shared.revertConfigOverrides(done);
      });
    }

    if(!_.isEmpty(newRuntimeConfig)) {
      before(function setupRuntimeConfig(done) {
        shared.setRuntimeConfigOverrides(newRuntimeConfig, done);
      });

      after(function revertRuntimeConfig(done) {
        // Longer timeout for our tests that change the mongodb primary server,
        // since we have to allow time for this local test connection to
        // reconnect to the primary.
        this.timeout(60000);

        shared.revertRuntimeConfigOverrides(done);
      });
    }

    before(function beforeWaitForConfig(done) {
      this.timeout(5000);
      shared.waitForConfig(done);
    });
    after(function afterWaitForConfig(done) {
      this.timeout(5000);
      shared.waitForConfig(done);
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
