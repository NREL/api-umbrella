'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    execFile = require('child_process').execFile,
    Factory = require('factory-lady'),
    processEnv = require('../../lib/process_env'),
    request = require('request'),
    supervisorPid = require('../../lib/supervisor_pid'),
    supervisorSignal = require('../../lib/supervisor_signal');

describe('processes', function() {
  describe('nginx', function() {
    it('does not leak file descriptors across reloads', function(done) {
      this.timeout(40000);

      var execOpts = { env: processEnv.env() };
      supervisorPid('router-nginx', function(error, parentPid) {
        if(error) {
          return done('Error fetching nginx pid: ' + error);
        }

        async.timesSeries(15, function(index, next) {
          supervisorSignal('router-nginx', 'SIGHUP', function(error) {
            if(error) {
              return next('Error reloading nginx: ' + error);
            }

            setTimeout(function() {
              execFile('lsof', ['-R', '-c', 'nginx'], execOpts, function(error, stdout, stderr) {
                if(error) {
                  return next('Error gathering lsof details: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr);
                }

                var lines = _.filter(stdout.split('\n'), function(line) {
                  var columns = line.split(/\s+/);
                  return parseInt(columns[2], 10) === parentPid;
                });
                setTimeout(function() {
                  next(null, lines.length);
                }, 500);
              });
            }, 500);
          });
        }, function(error, descriptorCounts) {
          if(error) {
            return done(error);
          }

          descriptorCounts.length.should.eql(15);
          descriptorCounts[0].should.be.greaterThan(0);
          _.uniq(descriptorCounts).length.should.eql(1);
          done();
        });
      });
    });
  });

  describe('reload', function() {
    before(function publishDbConfig(done) {
      this.timeout(10000);

      // Be sure that these tests interact with a backend published via Mongo,
      // so we can also catch errors for when the mongo-based configuration
      // data experiences failures.
      shared.publishDbConfig({
        apis: [
          {
            _id: 'db-config',
            frontend_host: 'localhost',
            backend_host: 'localhost',
            servers: [
              {
                host: '127.0.0.1',
                port: 9444,
              }
            ],
            url_matches: [
              {
                frontend_prefix: '/db-config/hello',
                backend_prefix: '/hello',
              }
            ],
          },
        ],
      }, done);
    });

    beforeEach(function setOptionDefaults(done) {
      Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
        this.user = user;
        this.apiKey = user.api_key;
        this.options = {
          followRedirect: false,
          headers: {
            'X-Api-Key': this.apiKey,
            'X-Disable-Router-Connection-Limits': 'yes',
            'X-Disable-Router-Rate-Limits': 'yes',
          },
          agentOptions: {
            maxSockets: 500,
          },
        };

        done();
      }.bind(this));
    });

    after(function removeDbConfig(done) {
      this.timeout(6000);

      // Remove DB-based config after these tests, so the rest of the tests go
      // back to the file-based configs.
      shared.removeDbConfig(done);
    });

    it('does not drop connections during reloads', function(done) {
      this.timeout(60000);

      var runTests = true;

      setTimeout(function() {
        this.router.reload(function(error) {
          should.not.exist(error);
          setTimeout(function() { runTests = false; }, 5000);
        });
      }.bind(this), 100);

      async.whilst(function() { return runTests; }, function(whilstCallback) {
        request.get('http://localhost:9080/db-config/hello', this.options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.eql('Hello World');

          whilstCallback(error);
        });
      }.bind(this), function(error) {
        should.not.exist(error);
        done();
      });
    });
  });
});
