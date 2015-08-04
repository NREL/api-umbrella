'use strict';

require('../test_helper');

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    async = require('async'),
    execFile = require('child_process').execFile,
    Factory = require('factory-lady'),
    fs = require('fs'),
    path = require('path'),
    processEnv = require('../support/process_env'),
    request = require('request');

var config = apiUmbrellaConfig.load(path.resolve(__dirname, '../config/test.yml'));

describe('processes', function() {
  shared.runServer();

  describe('nginx', function() {
    it('does not leak file descriptors across reloads', function(done) {
      this.timeout(50000);

      var execOpts = { env: processEnv.env() };
      var parentPid;
      var descriptorCounts = [];
      var urandomDescriptorCounts = [];

      async.series([
        // First, make a number of concurrent requests to ensure that each
        // nginx worker process is warmed up. This ensures that each worker
        // should at least have initialized its usage of its urandom
        // descriptors. Since we want to test that these descriptors don't
        // grow, we first need to ensure each worker process is first fully
        // initialized (so they don't grow due to be initialized later on in
        // the tests).
        function(callback) {
          async.times(50, function(index, next) {
            request.get('http://localhost:9080/delay/500', this.options, function(error, response) {
              response.statusCode.should.eql(200);
              next(error);
            });
          }.bind(this), callback);
        }.bind(this),

        // Next, fetch the PID of the nginx parent/master process.
        function(callback) {
          execFile('perpstat', ['-b', path.join(config.get('etc_dir'), 'perp'), 'gatekeeper-nginx'], execOpts, function(error, stdout, stderr) {
            if(error || !stdout) {
              return callback('Error fetching nginx pid: ' + error + ' (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
            }

            var match = stdout.match(/^\s*main:.*\(pid (\d+)\)\s*$/m);
            if(!match) {
              return callback('No PID returned for nginx (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
            }

            parentPid = parseInt(match[1], 10);
            callback();
          });
        },

        // Now perform a number of reloads and gather file descriptor
        // information after each one.
        function(callback) {
          async.timesSeries(15, function(index, timesNext) {
            async.series([
              // Send a reload signal to nginx.
              function(seriesNext) {
                execFile('kill', ['-HUP', parentPid], function(error, stdout, stderr) {
                  if(error) {
                    return seriesNext('Error reloading nginx: ' + error + ' (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
                  }

                  // Wait a little while after sending the reload signal to
                  // ensure the master process has had time to react.
                  setTimeout(seriesNext, 250);
                });
              },

              // After sending the reload signal, wait until only one set of
              // worker processes is running. This prevents us from checking
              // file descriptors when some of the old worker processes are
              // still alive, but in the process of shutting down.
              function(seriesNext) {
                var numWorkers;
                var expectedNumWorkers = config.get('nginx.workers') || 4;

                async.doUntil(function(untilNext) {
                  execFile('pgrep', ['-P', parentPid], function(error, stdout, stderr) {
                    if(error || !stdout) {
                      return seriesNext('Error reloading nginx: ' + error + ' (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
                    }

                    numWorkers = stdout.trim().split('\n').length;
                    setTimeout(untilNext, 50);
                  });
                }, function() {
                  return numWorkers === expectedNumWorkers;
                }, seriesNext);
              },

              // Now check for open file descriptors.
              function(seriesNext) {
                execFile('lsof', ['-R', '-c', 'nginx'], function(error, stdout, stderr) {
                  if(error) {
                    return seriesNext('Error gathering lsof details: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr);
                  }

                  var lines = stdout.split('\n');
                  var descriptorCount = 0;
                  var urandomDescriptorCount = 0;
                  lines.forEach(function(line) {
                    var columns = line.split(/\s+/);
                    if(parseInt(columns[1], 10) === parentPid || parseInt(columns[2], 10) === parentPid) {
                      descriptorCount++;

                      if(_.contains(line, 'urandom')) {
                        urandomDescriptorCount++;
                      }
                    }
                  });

                  descriptorCounts.push(descriptorCount);
                  urandomDescriptorCounts.push(urandomDescriptorCount);

                  setTimeout(function() {
                    seriesNext(null, lines.length);
                  }, 500);
                });
              },
            ], timesNext);
          }, callback);
        },
      ], function(error) {
        if(error) {
          return done(error);
        }

        // Test to ensure ngx_txid isn't leaving open file descriptors around
        // on reloads test for this patch:
        // https://github.com/streadway/ngx_txid/pull/6
        urandomDescriptorCounts.length.should.eql(15);
        urandomDescriptorCounts[0].should.be.greaterThan(0);
        _.max(urandomDescriptorCounts).should.eql(_.min(urandomDescriptorCounts));

        // A more general test to ensure that we don't see other unexpected
        // file descriptor growth. We'll allow some growth for this test,
        // though, just to account for small fluctuations in sockets due to
        // other things nginx may be doing.
        descriptorCounts.length.should.eql(15);
        _.min(descriptorCounts).should.be.greaterThan(0);
        var range = _.max(descriptorCounts) - _.min(descriptorCounts);
        range.should.be.lessThan(10);

        done();
      });
    });
  });

  describe('reload', function() {
    before(function publishDbConfig(done) {
      this.timeout(10000);

      // Be sure that these tests interact with a backend published via Mongo,
      // so we can also catch errors for when the mongo-based configuration
      // data experiences failures.
      shared.setRuntimeConfigOverrides({
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
      }, function(error) {
        should.not.exist(error);
        shared.waitForConfig(done);
      });
    });

    beforeEach(function setOptionDefaults(done) {
      Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
        this.user = user;
        this.apiKey = user.api_key;
        this.options = {
          followRedirect: false,
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

    after(function removeDbConfig(done) {
      this.timeout(6000);

      // Remove DB-based config after these tests, so the rest of the tests go
      // back to the file-based configs.
      shared.revertRuntimeConfigOverrides(function(error) {
        should.not.exist(error);
        shared.waitForConfig(done);
      });
    });

    it('updates templates with file-based config file changes', function(done) {
      this.timeout(90000);

      var nginxFile = path.join(config.get('etc_dir'), 'nginx/router.conf');
      var nginxConfig = fs.readFileSync(nginxFile).toString();
      nginxConfig.should.contain('worker_processes 4;');

      shared.setConfigOverrides({
        nginx: {
          workers: 1,
        },
      }, function(error) {
        should.not.exist(error);
        shared.waitForConfig(function(error) {
          should.not.exist(error);

          nginxConfig = fs.readFileSync(nginxFile).toString();
          nginxConfig.should.contain('worker_processes 1;');

          shared.setConfigOverrides({}, function(error) {
            should.not.exist(error);
            shared.waitForConfig(function(error) {
              should.not.exist(error);

              nginxConfig = fs.readFileSync(nginxFile).toString();
              nginxConfig.should.contain('worker_processes 4;');

              done();
            });
          });
        });
      });
    });

    it('does not drop connections during reloads', function(done) {
      this.timeout(60000);

      var execOpts = { env: processEnv.env() };
      var parentPid;
      var originalPids;
      var finalPids;

      async.series([
        // Fetch the PID of the nginx parent/master process.
        function(callback) {
          execFile('perpstat', ['-b', path.join(config.get('etc_dir'), 'perp'), 'gatekeeper-nginx'], execOpts, function(error, stdout, stderr) {
            if(error || !stdout) {
              return callback('Error fetching nginx pid: ' + error + ' (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
            }

            var match = stdout.match(/^\s*main:.*\(pid (\d+)\)\s*$/m);
            if(!match) {
              return callback('No PID returned for nginx (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
            }

            parentPid = parseInt(match[1], 10);
            callback();
          });
        },

        // Gather the worker ids at the start (so we can sanity check that the
        // reloads happened).
        function(callback) {
          execFile('pgrep', ['-P', parentPid], function(error, stdout, stderr) {
            if(error) {
              return callback('Error fetching nginx pid: ' + error + ' (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
            }

            originalPids = stdout.split('\n').sort();
            callback();
          });
        },

        // Make requests while performing nginx reloads.
        function(callback) {
          // Run tests for 10 seconds.
          var runTests = true;
          setTimeout(function() { runTests = false; }, 10000);

          // Randomly send reload signals every 50-500ms during the testing
          // period.
          async.whilst(function() { return runTests; }, function(whilstCallback) {
            setTimeout(function() {
              execFile('kill', ['-HUP', parentPid], function(error, stdout, stderr) {
                if(error) {
                  return whilstCallback('Error reloading nginx: ' + error + ' (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
                }

                whilstCallback();
              });
            }, _.random(50, 500));
          }, function(error) {
            should.not.exist(error);
          });

          // Constantly make requests.
          async.whilst(function() { return runTests; }, function(whilstCallback) {
            request.get('http://localhost:9080/db-config/hello', this.options, function(error, response, body) {
              should.not.exist(error);
              response.statusCode.should.eql(200);
              body.should.eql('Hello World');

              whilstCallback(error);
            });
          }.bind(this), callback);
        }.bind(this),

        // Gather the worker ids at the end (so we can sanity check that the
        // reloads happened).
        function(callback) {
          execFile('pgrep', ['-P', parentPid], function(error, stdout, stderr) {
            if(error) {
              return callback('Error fetching nginx pid: ' + error + ' (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
            }

            finalPids = stdout.split('\n').sort();
            callback();
          });
        },
      ], function(error) {
        if(error) {
          return done(error);
        }

        should.not.exist(error);
        finalPids.should.not.eql(originalPids);
        done();
      });
    });
  });
});
