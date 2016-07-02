'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    config = require('../support/config'),
    execFile = require('child_process').execFile,
    Factory = require('factory-lady'),
    fs = require('fs'),
    path = require('path'),
    processEnv = require('../support/process_env'),
    request = require('request');

describe('processes', function() {
  shared.runServer();

  describe('nginx', function() {
    beforeEach(function setOptionDefaults(done) {
      Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
        this.apiKey = user.api_key;
        this.options = {
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

    it('does not leak file descriptors across reloads', function(done) {
      this.timeout(180000);

      var execOpts = { env: processEnv.env() };
      var parentPid;
      var descriptorCounts = [];
      var urandomDescriptorCounts = [];

      async.series([
        // Fetch the PID of the nginx parent/master process.
        function(callback) {
          execFile('perpstat', ['-b', path.join(config.get('root_dir'), 'etc/perp'), 'nginx'], execOpts, function(error, stdout, stderr) {
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
            var originalChildPids = [];

            async.series([
              // Get the list of original nginx worker process PIDs on startup.
              function(seriesNext) {
                var expectedNumWorkers = config.get('nginx.workers');

                async.doUntil(function(untilNext) {
                  execFile('pgrep', ['-P', parentPid], function(error, stdout, stderr) {
                    if(error || !stdout) {
                      return seriesNext('Error fetching nginx worker pids: ' + error + ' (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
                    }

                    originalChildPids = stdout.trim().split('\n');
                    setTimeout(untilNext, 50);
                  });
                }, function() {
                  return originalChildPids.length === expectedNumWorkers;
                }, seriesNext);
              },

              // Send a reload signal to nginx.
              function(seriesNext) {
                execFile('kill', ['-HUP', parentPid], function(error, stdout, stderr) {
                  if(error) {
                    return seriesNext('Error reloading nginx: ' + error + ' (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
                  }

                  seriesNext();
                });
              },

              // After sending the reload signal, wait until only the new set
              // of worker processes is running. This prevents us from checking
              // file descriptors when some of the old worker processes are
              // still alive, but in the process of shutting down.
              function(seriesNext) {
                var newChildPids = [];
                var expectedNumWorkers = config.get('nginx.workers');

                async.doUntil(function(untilNext) {
                  execFile('pgrep', ['-P', parentPid], function(error, stdout, stderr) {
                    if(error || !stdout) {
                      return seriesNext('Error fetching nginx worker pids: ' + error + ' (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
                    }

                    newChildPids = stdout.trim().split('\n');
                    setTimeout(untilNext, 50);
                  });
                }, function() {
                  return _.intersection(newChildPids, originalChildPids).length === 0 && newChildPids.length === expectedNumWorkers;
                }, seriesNext);
              },

              // Make a number of concurrent requests to ensure that each nginx
              // worker process is warmed up. This ensures that each worker
              // should at least have initialized its usage of its urandom
              // descriptors. Since we want to test that these descriptors
              // don't grow, we first need to ensure each worker process is
              // first fully initialized (so they don't grow due to be
              // initialized later on in the tests).
              function(seriesNext) {
                async.timesLimit(200, 10, function(index, next) {
                  request.get('http://localhost:9080/delay/20?' + Math.random(), this.options, function(error, response) {
                    response.statusCode.should.eql(200);
                    next(error);
                  });
                }.bind(this), seriesNext);
              }.bind(this),

              // Now check for open file descriptors.
              function(seriesNext) {
                execFile('lsof', ['-n', '-P', '-l', '-R', '-c', 'nginx'], function(error, stdout, stderr) {
                  if(error) {
                    return seriesNext('Error gathering lsof details: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr);
                  }

                  var lines = stdout.split('\n');
                  var logLines = [];
                  var descriptorCount = 0;
                  var urandomDescriptorCount = 0;
                  lines.forEach(function(line, lineIndex) {
                    var columns = line.split(/\s+/);
                    var colPid = parseInt(columns[1], 10);
                    var colParentPid = parseInt(columns[2], 10);
                    var colType = columns[5];

                    // Only count lines from the lsof output that belong to
                    // this nginx's PID and aren't network sockets (we exclude
                    // those when checking for leaks, since it's expected that
                    // there's much more variation in those depending on the
                    // requests made by tests, keepalive connections, etc).
                    if((lineIndex === 0 || colPid === parentPid || colParentPid === parentPid) && !_.contains(['IPv4', 'IPv6', 'unix', 'sock'], colType)) {
                      // Re-sort the columns and store for logging. The
                      // re-sorting of columns just makes the output a bit
                      // friendlier for tools like vimdiff.
                      logLines.push(columns.slice(0, 1).concat(columns.slice(3)).concat(columns.slice(1, 3)).join('\t'));

                      descriptorCount++;

                      if(_.contains(line, 'urandom')) {
                        urandomDescriptorCount++;
                      }
                    }
                  });

                  descriptorCounts.push(descriptorCount);
                  urandomDescriptorCounts.push(urandomDescriptorCount);

                  // Log the outputs of each run. This is to help debugging in
                  // the case of failures (so we can more easily identify what
                  // specifically might be leaking).
                  var logPath = path.join(config.get('root_dir'), 'var/log/descriptor_leak_test' + index + '.log');
                  fs.writeFileSync(logPath, logLines.sort().join('\n'));

                  setTimeout(function() {
                    seriesNext(null);
                  }, 500);
                });
              },
            ], timesNext);
          }.bind(this), callback);
        }.bind(this),
      ], function(error) {
        if(error) {
          return done(error);
        }

        // Test to ensure ngx_txid isn't leaving open file descriptors around
        // on reloads test for this patch:
        // https://github.com/streadway/ngx_txid/pull/6
        // Allow for some small fluctuations in the /dev/urandom sockets, since
        // other nginx modules might also be using them.
        urandomDescriptorCounts.length.should.eql(15);
        urandomDescriptorCounts[0].should.be.greaterThan(0);
        var range = _.max(urandomDescriptorCounts) - _.min(urandomDescriptorCounts);
        range.should.be.lte(config.get('nginx.workers') * 2);

        // A more general test to ensure that we don't see other unexpected
        // file descriptor growth. We'll allow some growth for this test,
        // though, just to account for small fluctuations in sockets due to
        // other things nginx may be doing.
        descriptorCounts.length.should.eql(15);
        _.min(descriptorCounts).should.be.greaterThan(0);
        range = _.max(descriptorCounts) - _.min(descriptorCounts);
        range.should.be.lte(config.get('nginx.workers') * 2);

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
      shared.setDbConfigOverrides({
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
      shared.revertDbConfigOverrides(function(error) {
        should.not.exist(error);
        shared.waitForConfig(done);
      });
    });

    it('updates templates with file-based config changes', function(done) {
      this.timeout(10000);

      var nginxFile = path.join(config.get('root_dir'), 'etc/nginx/router.conf');
      var nginxConfig = fs.readFileSync(nginxFile).toString();
      nginxConfig.should.contain('worker_processes ' + config.get('nginx.workers') + ';');

      shared.setFileConfigOverrides({
        nginx: {
          workers: 1,
        },
      }, function(error) {
        should.not.exist(error);
        shared.waitForConfig(function(error) {
          should.not.exist(error);

          nginxConfig = fs.readFileSync(nginxFile).toString();
          nginxConfig.should.contain('worker_processes 1;');

          shared.setFileConfigOverrides({}, function(error) {
            should.not.exist(error);
            shared.waitForConfig(function(error) {
              should.not.exist(error);

              nginxConfig = fs.readFileSync(nginxFile).toString();
              nginxConfig.should.contain('worker_processes ' + config.get('nginx.workers') + ';');

              done();
            });
          });
        });
      });
    });

    it('updates apis with file-based config changes', function(done) {
      this.timeout(10000);

      async.series([
        function(callback) {
          request.get('http://localhost:9080/file-config/info/', this.options, function(error, response) {
            if(error) {
              return callback(error);
            }

            response.statusCode.should.eql(404);
            callback();
          });
        }.bind(this),
        function(callback) {
          shared.setFileConfigOverrides({
            apis: [
              {
                _id: 'file-config',
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
                    frontend_prefix: '/file-config/info/',
                    backend_prefix: '/info/',
                  }
                ],
                settings: {
                  headers: [
                    { key: 'X-Test-File-Config', value: 'foo' },
                  ],
                },
              },
            ],
          }, callback);
        },
        function(callback) {
          shared.waitForConfig(callback);
        },
        function(callback) {
          request.get('http://localhost:9080/file-config/info/', this.options, function(error, response, body) {
            if(error) {
              return callback(error);
            }

            response.statusCode.should.eql(200);
            var data = JSON.parse(body);
            data.headers['x-test-file-config'].should.eql('foo');

            callback();
          });
        }.bind(this),
        function(callback) {
          shared.setFileConfigOverrides({}, callback);
        },
        function(callback) {
          shared.waitForConfig(callback);
        },
        function(callback) {
          request.get('http://localhost:9080/file-config/info/', this.options, function(error, response) {
            if(error) {
              return callback(error);
            }

            response.statusCode.should.eql(404);
            callback();
          });
        }.bind(this),
      ], function(error) {
        should.not.exist(error);
        done();
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
          execFile('perpstat', ['-b', path.join(config.get('root_dir'), 'etc/perp'), 'nginx'], execOpts, function(error, stdout, stderr) {
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
          setTimeout(function() { runTests = false; }, 20000);

          // Randomly send reload signals every 5-500ms during the testing
          // period.
          async.whilst(function() { return runTests; }, function(whilstCallback) {
            setTimeout(function() {
              if(runTests) {
                shared.runCommand(['reload', '--router'], whilstCallback);
              }
            }, _.random(5, 500));
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
