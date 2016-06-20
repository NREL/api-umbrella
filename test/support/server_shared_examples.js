'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    csv = require('csv'),
    Factory = require('factory-lady'),
    fs = require('fs'),
    ippp = require('ipplusplus'),
    mergeOverwriteArrays = require('object-extend'),
    mongoose = require('mongoose'),
    path = require('path'),
    request = require('request'),
    uuid = require('node-uuid'),
    xml2js = require('xml2js'),
    yaml = require('js-yaml');

global.autoIncrementingIpAddress = '10.0.0.0';

_.merge(global.shared, {
  buildRequestOptions: function(path, apiKey, options) {
    return _.extend({
        url: 'http://localhost:9080' + path,
        qs: { api_key: apiKey },
      }, options);
  },

  setFileConfigOverrides: function setFileConfigOverrides(newFileConfig, callback) {
    global.currentFileConfigOverrides = newFileConfig;

    var overridesFileConfigPath = path.resolve(__dirname, '../config/.overrides.yml');

    var config = {};
    mergeOverwriteArrays(config, newFileConfig);

    // Generate a unique ID for this config, so we can detect when it's been
    // loaded.
    config.version = parseInt(_.uniqueId(), 10);
    global.currentFileConfigVersion = config.version;

    // Dump as YAML, with nulls being treated as real YAML nulls, rather than
    // the string "null" (which is js-yaml's default).
    fs.writeFileSync(overridesFileConfigPath, yaml.safeDump(config, { styles: { '!!null': 'canonical' } }));

    shared.runCommand(['reload', '--router'], callback);
  },

  revertFileConfigOverrides: function revertFileConfigOverrides(callback) {
    global.currentFileConfigVersion = undefined;
    var overridesFileConfigPath = path.resolve(__dirname, '../config/.overrides.yml');
    fs.writeFileSync(overridesFileConfigPath, '');
    shared.runCommand(['reload', '--router'], callback);
  },

  setDbConfigOverrides: function setDbConfigOverrides(newDbConfig, callback) {
    global.currentDbConfigOverrides = newDbConfig;

    if(newDbConfig.apis) {
      newDbConfig.apis.forEach(function(api) {
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
        config: newDbConfig,
      }, function(record) {
        global.currentDbConfigVersion = record.version.getTime();
        callback();
      });
    });
  },

  revertDbConfigOverrides: function revertDbConfigOverrides(callback) {
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
        global.currentDbConfigVersion = record.version.getTime();
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
      var options = {};

      // If we're performing global rate limit tests, use a different IP
      // address for each /state API request when trying to determine if the
      // config is published. This prevents us from accidentally hitting these
      // global rate limits in our rapid polling requests to determine if
      // things are ready.
      if(global.currentFileConfigOverrides && global.currentFileConfigOverrides.router && global.currentFileConfigOverrides.router.global_rate_limits) {
        global.autoIncrementingIpAddress = ippp.next(global.autoIncrementingIpAddress);
        options.headers = options.headers || {};
        options.headers['X-Forwarded-For'] = global.autoIncrementingIpAddress;
      }

      request.get('http://127.0.0.1:9080/api-umbrella/v1/state?' + Math.random(), options, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);

        data = JSON.parse(body);
        if(data['db_config_version'] === global.currentDbConfigVersion && data['file_config_version'] === global.currentFileConfigVersion) {
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
        callback('configuration did not load in the expected amount of time (global.currentDbConfigVersion: ' + global.currentDbConfigVersion + ' global.currentFileConfigVersion: ' + global.currentFileConfigVersion + ' data: ' + JSON.stringify(data));
      } else {
        callback();
      }
    });
  },

  runServer: function(configOverrides, options) {
    configOverrides = configOverrides || {};
    options = options || {};
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

    var dbConfigKeys = ['apis', 'website_backends'];
    var newFileConfig = _.omit(configOverrides, dbConfigKeys);
    var newDbConfig = _.pick(configOverrides, dbConfigKeys);

    if(!_.isEmpty(newFileConfig)) {
      before(function setupFileConfig(done) {
        this.timeout(20000);
        async.series([
          function(next) {
            shared.setFileConfigOverrides(newFileConfig, next);
          },
          function(next) {
            // Wait for the file config changes to become active before
            // proceeding.
            //
            // Note: It's important to wait for the file config changes before
            // allowing any potential database config changes to take place.
            // This prevents race conditions when the database changes are
            // dependent on the file config changes and the database config
            // changes might get read in by the old nginx workers before the
            // nginx reload processes the new file config.
            shared.waitForConfig(next);
          },
        ], done);
      });

      after(function revertFileConfig(done) {
        this.timeout(20000);
        async.series([
          function(next) {
            shared.revertFileConfigOverrides(next);
          },
          function(next) {
            // Wait for the file config revert to become active before
            // proceeding.
            shared.waitForConfig(next);
          },
        ], done);
      });
    }

    if(!_.isEmpty(newDbConfig)) {
      before(function setupDbConfig(done) {
        this.timeout(20000);
        async.series([
          function(next) {
            shared.setDbConfigOverrides(newDbConfig, next);
          },
          function(next) {
            // Wait for the database config changes to become active before
            // proceeding.
            shared.waitForConfig(next);
          },
        ], done);
      });

      after(function revertDbConfig(done) {
        // Longer timeout for our tests that change the mongodb primary server,
        // since we have to allow time for this local test connection to
        // reconnect to the primary.
        this.timeout(60000);

        async.series([
          function(next) {
            shared.revertDbConfigOverrides(next);
          },
          function(next) {
            // Wait for the database config revert to become active before
            // proceeding.
            shared.waitForConfig(next);
          },
        ], done);
      });
    }

    beforeEach(function createDefaultApiUser(done) {
      global.autoIncrementingIpAddress = ippp.next(global.autoIncrementingIpAddress);
      this.ipAddress = global.autoIncrementingIpAddress;

      var userOptions = options.user || {};
      Factory.create('api_user', userOptions, function(user) {
        this.user = user;
        this.apiKey = user.api_key;
        this.options = _.merge({}, {
          followRedirect: false,
          headers: {
            'X-Api-Key': this.apiKey,
          },
          agentOptions: {
            maxSockets: 500,
          },
        }, this.optionsOverrides || {});

        if(this.options.headers['X-Api-Key'] === null) {
          delete this.options.headers['X-Api-Key'];
        }

        done();
      }.bind(this));
    });
  },

  itBehavesLikeGatekeeperBlocked: function(path, statusCode, errorCode, options) {
    it('doesn\'t call the target app', function(done) {
      async.series([
        function(next) {
          request.get('http://127.0.0.1:9442/reset_backend_called', function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            next();
          });
        },
        function(next) {
          request.get('http://127.0.0.1:9442/backend_called', function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            body.should.eql('false');
            next();
          });
        },
        function(next) {
          request(shared.buildRequestOptions(path, this.apiKey, options), function(error) {
            should.not.exist(error);
            next();
          });
        }.bind(this),
        function(next) {
          request.get('http://127.0.0.1:9442/backend_called', function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            body.should.eql('false');
            next();
          });
        },
      ], done);
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
      async.series([
        function(next) {
          request.get('http://127.0.0.1:9442/reset_backend_called', function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            next();
          });
        },
        function(next) {
          request.get('http://127.0.0.1:9442/backend_called', function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            body.should.eql('false');
            next();
          });
        },
        function(next) {
          request(shared.buildRequestOptions(path, this.apiKey, options), function(error) {
            should.not.exist(error);
            next();
          });
        }.bind(this),
        function(next) {
          request.get('http://127.0.0.1:9442/backend_called', function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            body.should.eql('true');
            next();
          });
        },
      ], done);
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
