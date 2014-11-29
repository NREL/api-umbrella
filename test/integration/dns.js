'use strict';

require('../test_helper');

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    async = require('async'),
    dns = require('dns'),
    execFile = require('child_process').execFile,
    Factory = require('factory-lady'),
    fs = require('fs'),
    ipaddr = require('ipaddr.js'),
    path = require('path'),
    processEnv = require('../../lib/process_env'),
    request = require('request');

var config = apiUmbrellaConfig.load(path.resolve(__dirname, '../config/test.yml'));

describe('dns backend resolving', function() {
  function setDnsRecords(records, delay, callback) {
    var configContent = '';
    records.forEach(function(record) {
      configContent += 'local-data: "' + record + '"\n';
    });

    fs.writeFileSync(path.join(config.get('etc_dir'), 'test_env/unbound/active_test.conf'), configContent);

    var configPath = processEnv.supervisordConfigPath();
    var execOpts = {
      env: processEnv.env(),
    };

    execFile('supervisorctl', ['-c', configPath, 'kill', 'HUP', 'test-env-unbound'], execOpts, function(error, stdout, stderr) {
      if(error) {
        return callback('Error reloading unbound: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr);
      }

      setTimeout(callback, delay);
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

  before(function resolveHostnames(done) {
    this.timeout(5000);

    var hosts = [
      'httpbin.org',
      'use.opendns.com',
      'google.com',
      'yahoo.com',
      'bing.com',
      'amazon.com',
      'twitter.com',
      'github.com',
    ];

    this.ips = {};
    async.eachLimit(hosts, 3, function(host, next) {
      dns.lookup(host, function(error, ip) {
        this.ips[host] = ip;
        next();
      }.bind(this));
    }.bind(this), done);
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

  it('responds successfully when a valid hostname is given', function(done) {
    request.get('http://localhost:9080/dns/valid-hostname/html', this.options, function(error, response, body) {
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
    this.timeout(10000);
    request.get('http://localhost:9080/dns/invalid-hostname-begins-resolving/html', this.options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(502);

      setDnsRecords(['invalid-hostname-begins-resolving.ooga 60 A ' + this.ips['httpbin.org']], 2100, function(error) {
        should.not.exist(error);
        request.get('http://localhost:9080/dns/invalid-hostname-begins-resolving/html', this.options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Moby-Dick');

          done();
        }.bind(this));
      }.bind(this));
    }.bind(this));
  });

  it('refreshes the IP after the domain\'s TTL expires', function(done) {
    this.timeout(20000);

    setDnsRecords(['refresh-after-ttl-expires.ooga 8 A ' + this.ips['httpbin.org']], 2100, function(error) {
      should.not.exist(error);
      request.get('http://localhost:9080/dns/refresh-after-ttl-expires/', this.options, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        body.should.contain('httpbin.org');

        setDnsRecords(['refresh-after-ttl-expires.ooga 8 A ' + this.ips['use.opendns.com']], 0, function(error) {
          should.not.exist(error);
          async.timesSeries(5, function(index, next) {
            request.get('http://localhost:9080/dns/refresh-after-ttl-expires/', this.options, function(error, response, body) {
              should.not.exist(error);
              response.statusCode.should.eql(200);
              body.should.contain('httpbin.org');

              setTimeout(next, 1000);
            }.bind(this));
          }.bind(this), function() {
            setTimeout(function() {
              request.get('http://localhost:9080/dns/refresh-after-ttl-expires/', this.options, function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.eql(200);
                body.should.contain('OpenDNS');
                done();
              }.bind(this));
            }.bind(this), 4000);
          }.bind(this));
        }.bind(this));
      }.bind(this));
    }.bind(this));
  });

  it('takes a host down if it fails to resolve after the TTL expires', function(done) {
    this.timeout(20000);

    setDnsRecords(['down-after-ttl-expires.ooga 8 A ' + this.ips['httpbin.org']], 2100, function(error) {
      should.not.exist(error);
      request.get('http://localhost:9080/dns/down-after-ttl-expires/', this.options, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        body.should.contain('httpbin.org');

        setDnsRecords([], 0, function(error) {
          should.not.exist(error);
          async.timesSeries(5, function(index, next) {
            request.get('http://localhost:9080/dns/down-after-ttl-expires/', this.options, function(error, response, body) {
              should.not.exist(error);
              response.statusCode.should.eql(200);
              body.should.contain('httpbin.org');

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
    this.timeout(20000);

    async.series([
      function(next) {
        setDnsRecords(['ongoing-changes.ooga 1 A ' + this.ips['httpbin.org']], 2100, function(error) {
          should.not.exist(error);
          request.get('http://localhost:9080/dns/ongoing-changes/', this.options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            body.should.contain('httpbin.org');
            next();
          });
        }.bind(this));
      }.bind(this),
      function(next) {
        setDnsRecords(['ongoing-changes.ooga 1 A ' + this.ips['use.opendns.com']], 2100, function(error) {
          should.not.exist(error);
          request.get('http://localhost:9080/dns/ongoing-changes/', this.options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            body.should.contain('OpenDNS');
            next();
          });
        }.bind(this));
      }.bind(this),
      function(next) {
        setDnsRecords(['ongoing-changes.ooga 1 A ' + this.ips['google.com']], 2100, function(error) {
          should.not.exist(error);
          request.get('http://localhost:9080/dns/ongoing-changes/', this.options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(302);
            body.should.contain('google');
            next();
          });
        }.bind(this));
      }.bind(this),
      function(next) {
        setDnsRecords(['ongoing-changes.ooga 1 A ' + this.ips['yahoo.com']], 2100, function(error) {
          should.not.exist(error);
          request.get('http://localhost:9080/dns/ongoing-changes/', this.options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(404);
            body.should.contain('yahoo');
            next();
          });
        }.bind(this));
      }.bind(this),
    ], done);
  });

  it('load balances between multiple servers when the domain resolves to multiple IPs', function(done) {
    this.timeout(10000);

    var dnsRecords = _.map(this.localInterfaceIps, function(ip) {
      var type = (ipaddr.IPv6.isValid(ip)) ? 'AAAA' : 'A';
      return 'multiple-ips.ooga 60 ' + type + ' ' + ip;
    });

    setDnsRecords(dnsRecords, 2100, function(error) {
      should.not.exist(error);
      async.times(250, function(index, next) {
        request.get('http://localhost:9080/dns/multiple-ips/info/', this.options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          next(error, data.local_interface_ip);
        });
      }.bind(this), function(error, seenLocalInterfaceIps) {
        seenLocalInterfaceIps.length.should.eql(250);

        // Make sure all the different loopback IPs defined for this hostname
        // were actually used.
        _.uniq(seenLocalInterfaceIps).sort().should.eql(this.localInterfaceIps.sort());
        done();
      }.bind(this));
    }.bind(this));
  });

  it('handles ip changes without dropping any connections', function(done) {
    this.timeout(30000);

    var runTests = true;
    setTimeout(function() { runTests = false; }, 20000);

    var responseCodes = {};
    var seenLocalInterfaceIps = {};

    setDnsRecords(['no-drops-during-changes.ooga 1 A 127.0.0.1'], 2100, function(error) {
      should.not.exist(error);

      // Setup 25 parallel tasks to make requests in parallel.
      var tasks = [];
      _.times(25, function() {
        tasks.push(function(parallelCallback) {
          async.whilst(function() { return runTests; }, function(whilstCallback) {
            this.options.headers['X-Api-Umbrella-Backend-Scheme'] = 'http';
            this.options.headers['X-Api-Umbrella-Backend-Id'] = 'dns-no-drops-during-changes';
            request.get('http://localhost:13011/info/', this.options, function(error, response, body) {
            //request.get('http://localhost:9080/dns/no-drops-during-changes/info/', this.options, function(error, response, body) {
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

      async.parallel(tasks, function(error) {
        should.not.exist(error);

        // Ensure that all the responses were successful.
        _.keys(responseCodes).should.eql(['200']);

        // Ensure we saw a mix of the different loopback addresses in effect
        // (ideally, we'd ensure that we saw all the addresses, but given the
        // randomness of this test, we'll just ensure we saw at least a
        // couple).
        _.uniq(_.keys(seenLocalInterfaceIps)).length.should.be.gte(2);
        done();
      }.bind(this));

      // While the requests are being made in parallel, change the DNS for this
      // domain.
      async.whilst(function() { return true; }, function(whilstCallback) {
        // Use a random local IP to trigger change.
        var randomIp = _.sample(this.localInterfaceIps);

        // Make sure things work with both a short TTL and no TTL.
        var randomTtl = _.sample([0, 1]);

        var type = (ipaddr.IPv6.isValid(randomIp)) ? 'AAAA' : 'A';
        var record = 'no-drops-during-changes.ooga ' + randomTtl + ' ' + type + ' ' + randomIp;
        setDnsRecords([record], 0, function(error) {
          should.not.exist(error);

          // Change the DNS again in less than a second.
          var again = _.random(0, 1000);
          setTimeout(whilstCallback, again);
        });
      }.bind(this), function() {});
    }.bind(this));
  });
});
