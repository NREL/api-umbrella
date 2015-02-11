'use strict';

require('../test_helper');

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    async = require('async'),
    execFile = require('child_process').execFile,
    Factory = require('factory-lady'),
    fs = require('fs'),
    ipaddr = require('ipaddr.js'),
    path = require('path'),
    processEnv = require('../../lib/process_env'),
    request = require('request'),
    Tail = require('tail').Tail;

var config = apiUmbrellaConfig.load(path.resolve(__dirname, '../config/test.yml'));

describe('dns backend resolving', function() {
  function setDnsRecords(records, options, callback) {
    // Write the unbound config file.
    var configContent = '';
    records.forEach(function(record) {
      configContent += 'local-data: "' + record + '"\n';
    });
    fs.writeFileSync(path.join(config.get('etc_dir'), 'test_env/unbound/active_test.conf'), configContent);

    if(options.wait) {
      // Detect when the DNS changes have actually been read-in and nginx has
      // been reloaded by tailing the log file.
      var logFile = path.join(config.get('log_dir'), 'config-reloader.log');
      var logTail;
      var logTailTimeout = setTimeout(function() {
        if(logTail) { logTail.unwatch(); }
        callback('nginx reload not detected in log file ' + logFile);
      }, 5000);
      logTail = new Tail(logFile);
      logTail.on('line', function(line) {
        if(_.contains(line, 'nginx reload signal sent')) {
          clearTimeout(logTailTimeout);
          logTail.unwatch();

          // Wait another 1.5s before calling the callback, since we just know
          // when the nginx reload signal is sent, but it takes nginx a little
          // while to actually reload the processes.
          setTimeout(callback, 1500);
        }
      });
    }

    // Reload unbound to read the new config file.
    var configPath = processEnv.supervisordConfigPath();
    var execOpts = {
      env: processEnv.env(),
    };
    execFile('supervisorctl', ['-c', configPath, 'kill', 'HUP', 'test-env-unbound'], execOpts, function(error, stdout, stderr) {
      if(error) {
        clearTimeout(logTailTimeout);
        logTail.unwatch();
        return callback('Error reloading unbound: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr);
      }

      if(!options.wait) {
        callback();
      }
    });
  }

  before(function setLocalInterfaceIps() {
    this.localInterfaceIps = [
      '127.0.0.1',
      '127.0.0.2',
      '127.0.0.3',
      '127.0.0.4',
      '127.0.0.5',
    ];
  });

  after(function clearDnsRecords(done) {
    this.timeout(5000);

    // Remove any custom DNS entries to prevent rapid reloads (for short TTL
    // records) after these DNS tests finish.
    setDnsRecords([], { wait: false }, function(error) {
      should.not.exist(error);
      done();
    });
  });

  beforeEach(function(done) {
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

  it('responds successfully when an ipv4 address is given', function(done) {
    request.get('http://localhost:9080/dns/ipv4/info/', this.options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      done();
    });
  });

  it('responds successfully when an ipv6 address is given', function(done) {
    request.get('http://localhost:9080/dns/ipv6/info/', this.options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      done();
    });
  });

  it('responds successfully when localhost is given', function(done) {
    request.get('http://localhost:9080/dns/localhost/info/', this.options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      done();
    });
  });

  it('responds successfully when a valid external hostname (httpbin.org) is given', function(done) {
    // Increase timeout in case external httpbin.org site is slow.
    this.timeout(10000);

    request.get('http://localhost:9080/dns/valid-external-hostname/html', this.options, function(error, response, body) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      body.should.contain('Moby-Dick');
      done();
    });
  });

  it('responds with a 502 error when an invalid hostname is given', function(done) {
    request.get('http://localhost:9080/dns/invalid-hostname/', this.options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(502);
      done();
    });
  });

  it('brings a host up if a previously invalid hostname begins resolving', function(done) {
    this.timeout(12000);

    request.get('http://localhost:9080/dns/invalid-hostname-begins-resolving/html', this.options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(502);

      setDnsRecords(['invalid-hostname-begins-resolving.ooga 60 A 127.0.0.1'], { wait: true }, function(error) {
        should.not.exist(error);
        request.get('http://localhost:9080/dns/invalid-hostname-begins-resolving/info/', this.options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.local_interface_ip.should.eql('127.0.0.1');
          done();
        }.bind(this));
      }.bind(this));
    }.bind(this));
  });

  it('refreshes the IP after the domain\'s TTL expires', function(done) {
    this.timeout(25000);

    setDnsRecords(['refresh-after-ttl-expires.ooga 8 A 127.0.0.1'], { wait: true }, function(error) {
      should.not.exist(error);
      request.get('http://localhost:9080/dns/refresh-after-ttl-expires/info/', this.options, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.local_interface_ip.should.eql('127.0.0.1');

        setDnsRecords(['refresh-after-ttl-expires.ooga 8 A 127.0.0.2'], { wait: false }, function(error) {
          should.not.exist(error);
          async.timesSeries(5, function(index, next) {
            request.get('http://localhost:9080/dns/refresh-after-ttl-expires/info/', this.options, function(error, response, body) {
              should.not.exist(error);
              response.statusCode.should.eql(200);
              var data = JSON.parse(body);
              data.local_interface_ip.should.eql('127.0.0.1');

              setTimeout(next, 1000);
            }.bind(this));
          }.bind(this), function() {
            setTimeout(function() {
              request.get('http://localhost:9080/dns/refresh-after-ttl-expires/info/', this.options, function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.eql(200);
                var data = JSON.parse(body);
                data.local_interface_ip.should.eql('127.0.0.2');

                done();
              }.bind(this));
            }.bind(this), 4000);
          }.bind(this));
        }.bind(this));
      }.bind(this));
    }.bind(this));
  });

  it('takes a host down if it fails to resolve after the TTL expires', function(done) {
    this.timeout(25000);

    setDnsRecords(['down-after-ttl-expires.ooga 8 A 127.0.0.1'], { wait: true }, function(error) {
      should.not.exist(error);
      request.get('http://localhost:9080/dns/down-after-ttl-expires/info/', this.options, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.local_interface_ip.should.eql('127.0.0.1');

        setDnsRecords([], { wait: false }, function(error) {
          should.not.exist(error);
          async.timesSeries(5, function(index, next) {
            request.get('http://localhost:9080/dns/down-after-ttl-expires/info/', this.options, function(error, response, body) {
              should.not.exist(error);
              response.statusCode.should.eql(200);
              var data = JSON.parse(body);
              data.local_interface_ip.should.eql('127.0.0.1');

              setTimeout(next, 1000);
            }.bind(this));
          }.bind(this), function() {
            setTimeout(function() {
              request.get('http://localhost:9080/dns/down-after-ttl-expires/', this.options, function(error, response) {
                should.not.exist(error);
                response.statusCode.should.eql(502);
                done();
              }.bind(this));
            }.bind(this), 4000);
          }.bind(this));
        }.bind(this));
      }.bind(this));
    }.bind(this));
  });

  it('handles ongoing changes to the domain', function(done) {
    this.timeout(25000);

    async.series([
      function(next) {
        setDnsRecords(['ongoing-changes.ooga 1 A 127.0.0.1'], { wait: true }, function(error) {
          should.not.exist(error);
          request.get('http://localhost:9080/dns/ongoing-changes/info/', this.options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            var data = JSON.parse(body);
            data.local_interface_ip.should.eql('127.0.0.1');
            next();
          });
        }.bind(this));
      }.bind(this),
      function(next) {
        setDnsRecords(['ongoing-changes.ooga 1 A 127.0.0.2'], { wait: true }, function(error) {
          should.not.exist(error);
          request.get('http://localhost:9080/dns/ongoing-changes/info/', this.options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            var data = JSON.parse(body);
            data.local_interface_ip.should.eql('127.0.0.2');
            next();
          });
        }.bind(this));
      }.bind(this),
      function(next) {
        setDnsRecords(['ongoing-changes.ooga 1 A 127.0.0.3'], { wait: true }, function(error) {
          should.not.exist(error);
          request.get('http://localhost:9080/dns/ongoing-changes/info/', this.options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            var data = JSON.parse(body);
            data.local_interface_ip.should.eql('127.0.0.3');
            next();
          });
        }.bind(this));
      }.bind(this),
      function(next) {
        setDnsRecords(['ongoing-changes.ooga 1 A 127.0.0.4'], { wait: true }, function(error) {
          should.not.exist(error);
          request.get('http://localhost:9080/dns/ongoing-changes/info/', this.options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            var data = JSON.parse(body);
            data.local_interface_ip.should.eql('127.0.0.4');
            next();
          });
        }.bind(this));
      }.bind(this),
    ], done);
  });

  it('load balances between multiple servers when the domain resolves to multiple IPs', function(done) {
    this.timeout(15000);

    var dnsRecords = _.map(this.localInterfaceIps, function(ip) {
      var type = (ipaddr.IPv6.isValid(ip)) ? 'AAAA' : 'A';
      return 'multiple-ips.ooga 60 ' + type + ' ' + ip;
    });

    var responseCodes = {};
    var seenLocalInterfaceIps = {};

    setDnsRecords(dnsRecords, { wait: true }, function(error) {
      should.not.exist(error);

      async.times(250, function(index, timesCallback) {
        request.get('http://localhost:9080/dns/multiple-ips/info/', this.options, function(error, response, body) {
          if(!error) {
            responseCodes[response.statusCode] = responseCodes[response.statusCode] || 0;
            responseCodes[response.statusCode]++;

            if(response.statusCode === 200) {
              var data = JSON.parse(body);
              seenLocalInterfaceIps[data.local_interface_ip] = seenLocalInterfaceIps[data.local_interface_ip] || 0;
              seenLocalInterfaceIps[data.local_interface_ip]++;
            }
          }

          timesCallback(error);
        });
      }.bind(this), function(error) {
        should.not.exist(error);

        // Ensure that all the responses were successful.
        _.keys(responseCodes).should.eql(['200']);
        responseCodes['200'].should.eql(250);

        // Make sure all the different loopback IPs defined for this hostname
        // were actually used.
        _.uniq(_.keys(seenLocalInterfaceIps)).sort().should.eql(this.localInterfaceIps.sort());

        done();
      }.bind(this));
    }.bind(this));
  });

  it('handles ip changes without dropping any connections', function(done) {
    this.timeout(35000);

    var runTests = true;
    setTimeout(function() { runTests = false; }, 20000);

    var responseCodes = {};
    var seenLocalInterfaceIps = {};

    setDnsRecords(['no-drops-during-changes.ooga 1 A 127.0.0.1'], { wait: true }, function(error) {
      should.not.exist(error);

      // Setup 25 parallel tasks to make requests in parallel.
      var tasks = [];
      _.times(25, function() {
        tasks.push(function(parallelCallback) {
          async.whilst(function() { return runTests; }, function(whilstCallback) {
            request.get('http://localhost:9080/dns/no-drops-during-changes/info/', this.options, function(error, response, body) {
              if(!error) {
                // For each request, keep track of the response code and the
                // local interface IP address this request hit.
                responseCodes[response.statusCode] = responseCodes[response.statusCode] || 0;
                responseCodes[response.statusCode]++;

                if(response.statusCode === 200) {
                  var data = JSON.parse(body);
                  seenLocalInterfaceIps[data.local_interface_ip] = seenLocalInterfaceIps[data.local_interface_ip] || 0;
                  seenLocalInterfaceIps[data.local_interface_ip]++;
                }
              }

              whilstCallback(error);
            }, function() {});
          }.bind(this), parallelCallback);
        }.bind(this));
      }.bind(this));

      var runningTests = true;
      async.parallel(tasks, function(error) {
        should.not.exist(error);

        // Ensure that all the responses were successful.
        _.keys(responseCodes).should.eql(['200']);

        // Ensure we saw a mix of the different loopback addresses in effect
        // (ideally, we'd ensure that we saw all the addresses, but given the
        // randomness of this test, we'll just ensure we saw at least a
        // couple).
        _.uniq(_.keys(seenLocalInterfaceIps)).length.should.be.gte(2);

        runningTests = false;
        done();
      }.bind(this));

      // While the requests are being made in parallel, change the DNS for this
      // domain.
      async.whilst(function() { return runningTests; }, function(whilstCallback) {
        // Use a random local IP to trigger change.
        var randomIp = _.sample(this.localInterfaceIps);

        // Make sure things work with both a short TTL and no TTL.
        var randomTtl = _.sample([0, 1]);

        var type = (ipaddr.IPv6.isValid(randomIp)) ? 'AAAA' : 'A';
        var record = 'no-drops-during-changes.ooga ' + randomTtl + ' ' + type + ' ' + randomIp;
        setDnsRecords([record], { wait: false }, function(error) {
          should.not.exist(error);

          // Change the DNS again in less than a second.
          var again = _.random(0, 1000);
          setTimeout(whilstCallback, again);
        });
      }.bind(this), function() {});
    }.bind(this));
  });

  it('resolves new api backends when they are published', function(done) {
    this.timeout(30000);

    setDnsRecords(['newly-published-backend.ooga 60 A 127.0.0.2'], { wait: false }, function(error) {
      should.not.exist(error);

      shared.publishDbConfig({
        apis: [
          {
            _id: 'dns-newly-published-backend',
            frontend_host: 'localhost',
            backend_host: 'newly-published-backend.ooga',
            servers: [
              {
                host: 'newly-published-backend.ooga',
                port: 9444,
              }
            ],
            url_matches: [
              {
                frontend_prefix: '/dns/newly-published-backend/',
                backend_prefix: '/',
              }
            ],
          },
        ],
      }, function(error) {
        should.not.exist(error);

        request.get('http://localhost:9080/dns/newly-published-backend/info/', this.options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.local_interface_ip.should.eql('127.0.0.2');
          done();
        });
      }.bind(this));
    }.bind(this));
  });
});
