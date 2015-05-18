'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    csv = require('csv'),
    execFile = require('child_process').execFile,
    Factory = require('factory-lady'),
    fs = require('fs'),
    fsExtra = require('fs-extra'),
    ippp = require('ipplusplus'),
    mergeOverwriteArrays = require('object-extend'),
    mongoose = require('mongoose'),
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

  runServer: function(configOverrides) {
    if(!configOverrides) {
      configOverrides = {
        apis: [
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
        ],
      };
    }

    var runtimeKeys = ['apis', 'website_backends'];
    var newConfig = _.omit(configOverrides, runtimeKeys);
    var newRuntimeConfig = _.pick(configOverrides, runtimeKeys);

    if(!_.isEmpty(newConfig)) {
      before(function setupConfig(done) {
        var runtimeConfigPath = '/tmp/api-umbrella-test/var/run/runtime_config.yml';
        var data = fs.readFileSync(runtimeConfigPath + '.orig');
        var config = yaml.safeLoad(data.toString());
        mergeOverwriteArrays(config, newConfig);

        // Generate a unique ID for this config, so we can detect when it's been
        // loaded.
        config.config_id = uuid.v4();
        this.currentConfigId = config.config_id;

        // Dump as YAML, with nulls being treated as real YAML nulls, rather than
        // the string "null" (which is js-yaml's default).
        fs.writeFileSync(runtimeConfigPath, yaml.safeDump(config, { styles: { '!!null': 'canonical' } }));

        execFile('pkill', ['-HUP', '-f', 'nginx: master'], done);
      });

      after(function revertConfig(done) {
        this.currentConfigId = undefined;
        var runtimeConfigPath = '/tmp/api-umbrella-test/var/run/runtime_config.yml';
        fsExtra.copySync(runtimeConfigPath + '.orig', runtimeConfigPath);
        execFile('pkill', ['-HUP', '-f', 'nginx: master'], done);
      });
    }

    if(!_.isEmpty(newRuntimeConfig)) {
      before(function setupRuntimeConfig(done) {
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
            this.currentRuntimeConfigVersion = record.version.getTime();
            done();
          }.bind(this));
        }.bind(this));
      });

      after(function revertRuntimeConfig(done) {
        mongoose.testConnection.model('RouterConfigVersion').remove({}, function(error) {
          should.not.exist(error);

          Factory.create('config_version', {
            config: {},
          }, function(record) {
            this.currentRuntimeConfigVersion = record.version.getTime();
            done();
          }.bind(this));
        }.bind(this));
      });
    }

    function waitForConfig(done) {
      /* jshint validthis:true */
      this.timeout(5000);

      var configLoaded = false;
      var timedOut = false;
      setTimeout(function() { timedOut = true; }, 4800);

      async.until(function() {
        return configLoaded || timedOut;
      }, function(callback) {
        request.get('http://127.0.0.1:9080/api-umbrella/v1/state', function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);

          var data = JSON.parse(body);
          if(data['runtime_config_version'] === this.currentRuntimeConfigVersion && data['config_id'] === this.currentConfigId) {
            configLoaded = true;
            return callback();
          }

          setTimeout(callback, 10);
        }.bind(this));
      }.bind(this), function() {
        if(!configLoaded) {
          done('configuration did not load in the expected amount of time');
        } else {
          done();
        }
      });
    }

    before(waitForConfig);
    after(waitForConfig);

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
