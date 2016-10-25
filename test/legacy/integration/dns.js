'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    config = require('../support/config'),
    exec = require('child_process').exec,
    execFile = require('child_process').execFile,
    fs = require('fs'),
    ipaddr = require('ipaddr.js'),
    path = require('path'),
    processEnv = require('../support/process_env'),
    request = require('request');

// When checking to make sure we adhere to TTLs on the domain names, add a
// buffer to our timing calculations. This is to account for some fuzziness in
// our timings between what's happening in nginx and our test requests being
// made.
var TTL_BUFFER = 1.3;

describe('dns backend resolving', function() {
  function setDnsRecords(records, callback) {
    async.series([
      function(next) {
        // Write the unbound config file.
        var configContent = '';
        records.forEach(function(record) {
          configContent += 'local-data: \'' + record + '\'\n';
        });
        fs.writeFile(path.join(config.get('root_dir'), 'etc/test-env/unbound/active_test.conf'), configContent, next);
      },
      function(next) {
        // Reload unbound to read the new config file.
        var execOpts = { env: processEnv.env() };
        execFile('perpctl', ['-b', path.join(config.get('root_dir'), 'etc/perp'), 'hup', 'test-env-unbound'], execOpts, function(error, stdout, stderr) {
          if(error) {
            return next('Error reloading unbound: ' + error + ' (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
          }

          next();
        });
      },
    ], callback);
  }

  function waitForResponse(path, options, requestOptions, callback) {
    var finished = false;
    var startTime = new Date();
    async.doUntil(function(untilCallback) {
      request.get('http://localhost:9080' + path + '?waiting', requestOptions, function(error, response, body) {
        should.not.exist(error);

        var localInterfaceIp;
        if(response.statusCode === 200) {
          var data = JSON.parse(body);
          localInterfaceIp = data.local_interface_ip;
        }

        if(options.statusCode === response.statusCode) {
          if(options.localInterfaceIp) {
            if(options.localInterfaceIp === localInterfaceIp) {
              finished = true;
            }
          } else {
            finished = true;
          }
        }

        if(finished) {
          untilCallback();
        } else {
          setTimeout(untilCallback, 100);
        }
      });
    }, function() {
      return finished || (new Date() - startTime) > 15000;
    }, function() {
      if(!finished) {
        callback('response change not detected');
      } else {
        // After we detect the change we want, wait an additional 500ms. This
        // is to handle the fact that even though we've seen the desired state,
        // it may take some additional time before this update has propagated
        // to all nginx workers. This is due to how dyups works, so we must
        // wait a bit longer than the configured dyups_read_msg_timeout time.
        setTimeout(callback, 500);
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
    this.timeout(10000);

    // Remove any custom DNS entries to prevent rapid reloads (for short TTL
    // records) after these DNS tests finish.
    setDnsRecords([], done);
  });

  describe('default dns servers detected from /etc/resolv.conf', function() {
    shared.runServer({
      apis: [
        {
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
              frontend_prefix: '/info/ipv4/',
              backend_prefix: '/info/ipv4/',
            },
          ],
        },
        {
          frontend_host: 'localhost',
          backend_host: 'localhost',
          servers: [
            {
              host: '::1',
              port: 9444,
            },
          ],
          url_matches: [
            {
              frontend_prefix: '/info/ipv6/',
              backend_prefix: '/info/ipv6/',
            },
          ],
        },
        {
          frontend_host: 'localhost',
          backend_host: 'localhost',
          servers: [
            {
              host: 'localhost',
              port: 9444,
            },
          ],
          url_matches: [
            {
              frontend_prefix: '/info/localhost/',
              backend_prefix: '/info/localhost/',
            },
          ],
        },
        {
          frontend_host: 'localhost',
          backend_host: 'www.google.com',
          backend_protocol: 'https',
          servers: [
            {
              host: 'www.google.com',
              port: 443,
            },
          ],
          url_matches: [
            {
              frontend_prefix: '/valid-external-hostname/',
              backend_prefix: '/',
            },
          ],
        },
        {
          frontend_host: 'localhost',
          backend_host: 'invalid.ooga',
          servers: [
            {
              host: 'invalid.ooga',
              port: 9444,
            },
          ],
          url_matches: [
            {
              frontend_prefix: '/info/invalid-hostname/',
              backend_prefix: '/info/invalid-hostname/',
            },
          ],
        },
      ],
    }, {
      user: { settings: { rate_limit_mode: 'unlimited' } },
    });

    it('responds successfully when an ipv4 address is given', function(done) {
      request.get('http://localhost:9080/info/ipv4/', this.options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        done();
      });
    });

    it('responds successfully when an ipv6 address is given', function(done) {
      request.get('http://localhost:9080/info/ipv6/', this.options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        done();
      });
    });

    it('responds successfully when localhost is given', function(done) {
      request.get('http://localhost:9080/info/localhost/', this.options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        done();
      });
    });

    it('responds successfully when a valid external hostname (google.com) is given', function(done) {
      request.get('http://localhost:9080/valid-external-hostname/humans.txt', this.options, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        body.should.contain('Google is built by a large team');
        done();
      });
    });

    it('responds with a 502 error when an invalid hostname is given', function(done) {
      request.get('http://localhost:9080/info/invalid-hostname/', this.options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(502);
        done();
      });
    });
  });

  describe('custom dns servers for testing live changes', function() {
    describe('without caching', function() {
      shared.runServer({
        dns_resolver: {
          nameservers: [
            '[127.0.0.1]:' + config.get('unbound.port'),
          ],
          max_stale: 0,
          negative_ttl: false,
        },
        apis: [
          {
            frontend_host: 'localhost',
            backend_host: 'invalid-hostname-begins-resolving.ooga',
            servers: [
              {
                host: 'invalid-hostname-begins-resolving.ooga',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/info/invalid-hostname-begins-resolving/',
                backend_prefix: '/info/invalid-hostname-begins-resolving/',
              },
            ],
          },
          {
            frontend_host: 'localhost',
            backend_host: 'refresh-after-ttl-expires.ooga',
            servers: [
              {
                host: 'refresh-after-ttl-expires.ooga',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/info/refresh-after-ttl-expires/',
                backend_prefix: '/info/refresh-after-ttl-expires/',
              },
            ],
          },
          {
            frontend_host: 'localhost',
            backend_host: 'down-after-ttl-expires.ooga',
            servers: [
              {
                host: 'down-after-ttl-expires.ooga',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/info/down-after-ttl-expires/',
                backend_prefix: '/info/down-after-ttl-expires/',
              },
            ],
          },
          {
            frontend_host: 'localhost',
            backend_host: 'ongoing-changes.ooga',
            servers: [
              {
                host: 'ongoing-changes.ooga',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/info/ongoing-changes/',
                backend_prefix: '/info/ongoing-changes/',
              },
            ],
          },
          {
            frontend_host: 'localhost',
            backend_host: 'localhost',
            servers: [
              {
                host: 'multiple-ips.ooga',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/info/multiple-ips/',
                backend_prefix: '/info/multiple-ips/',
              },
            ],
          },
          {
            frontend_host: 'localhost',
            backend_host: 'localhost',
            servers: [
              {
                host: 'no-drops-during-changes.ooga',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/info/no-drops-during-changes/',
                backend_prefix: '/info/no-drops-during-changes/',
              },
            ],
          },
        ],
      }, {
        user: { settings: { rate_limit_mode: 'unlimited' } },
      });

      it('brings a host up if a previously invalid hostname begins resolving', function(done) {
        this.timeout(20000);

        async.series([
          function(next) {
            request.get('http://localhost:9080/info/invalid-hostname-begins-resolving/', this.options, function(error, response) {
              should.not.exist(error);
              response.statusCode.should.eql(502);
              next();
            });
          }.bind(this),
          function(next) {
            setDnsRecords(['invalid-hostname-begins-resolving.ooga 60 A 127.0.0.1'], next);
          },
          function(next) {
            waitForResponse('/info/invalid-hostname-begins-resolving/', { statusCode: 200, localInterfaceIp: '127.0.0.1' }, this.options, next);
          }.bind(this),
        ], done);
      });

      it('refreshes the IP after the domain\'s TTL expires', function(done) {
        this.timeout(25000);

        var ttl = 4;
        var startTtlCounterTime;
        async.series([
          function(next) {
            setDnsRecords(['refresh-after-ttl-expires.ooga ' + ttl + ' A 127.0.0.1'], next);
          },
          function(next) {
            waitForResponse('/info/refresh-after-ttl-expires/', { statusCode: 200, localInterfaceIp: '127.0.0.1' }, this.options, next);
          }.bind(this),
          function(next) {
            startTtlCounterTime = new Date();
            setDnsRecords(['refresh-after-ttl-expires.ooga ' + ttl + ' A 127.0.0.2'], next);
          },
          function(next) {
            waitForResponse('/info/refresh-after-ttl-expires/', { statusCode: 200, localInterfaceIp: '127.0.0.2' }, this.options, next);
          }.bind(this),
          function(next) {
            var endTtlCounterTime = new Date();
            var duration = endTtlCounterTime - startTtlCounterTime;
            duration.should.be.gte((ttl - TTL_BUFFER) * 1000);
            duration.should.be.lte((ttl + TTL_BUFFER) * 1000);
            next();
          },
        ], done);
      });

      it('takes a host down if it fails to resolve after the TTL expires', function(done) {
        this.timeout(25000);

        var ttl = 4;
        var startTtlCounterTime;
        async.series([
          function(next) {
            setDnsRecords(['down-after-ttl-expires.ooga ' + ttl + ' A 127.0.0.1'], next);
          },
          function(next) {
            waitForResponse('/info/down-after-ttl-expires/', { statusCode: 200, localInterfaceIp: '127.0.0.1' }, this.options, next);
          }.bind(this),
          function(next) {
            startTtlCounterTime = new Date();
            setDnsRecords([], next);
          },
          function(next) {
            waitForResponse('/info/down-after-ttl-expires/', { statusCode: 502 }, this.options, next);
          }.bind(this),
          function(next) {
            var endTtlCounterTime = new Date();
            var duration = endTtlCounterTime - startTtlCounterTime;
            duration.should.be.gte((ttl - TTL_BUFFER) * 1000);
            duration.should.be.lte((ttl + TTL_BUFFER) * 1000);
            next();
          },
        ], done);
      });

      it('handles ongoing changes to the domain', function(done) {
        this.timeout(25000);

        async.series([
          function(next) {
            setDnsRecords(['ongoing-changes.ooga 1 A 127.0.0.1'], next);
          },
          function(next) {
            waitForResponse('/info/ongoing-changes/', { statusCode: 200, localInterfaceIp: '127.0.0.1' }, this.options, next);
          }.bind(this),
          function(next) {
            setDnsRecords(['ongoing-changes.ooga 1 A 127.0.0.2'], next);
          },
          function(next) {
            waitForResponse('/info/ongoing-changes/', { statusCode: 200, localInterfaceIp: '127.0.0.2' }, this.options, next);
          }.bind(this),
          function(next) {
            setDnsRecords(['ongoing-changes.ooga 1 A 127.0.0.3'], next);
          },
          function(next) {
            waitForResponse('/info/ongoing-changes/', { statusCode: 200, localInterfaceIp: '127.0.0.3' }, this.options, next);
          }.bind(this),
          function(next) {
            setDnsRecords(['ongoing-changes.ooga 1 A 127.0.0.4'], next);
          },
          function(next) {
            waitForResponse('/info/ongoing-changes/', { statusCode: 200, localInterfaceIp: '127.0.0.4' }, this.options, next);
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

        async.series([
          function(next) {
            setDnsRecords(dnsRecords, next);
          },
          function(next) {
            waitForResponse('/info/multiple-ips/', { statusCode: 200 }, this.options, next);
          }.bind(this),
          function(next) {
            async.times(250, function(index, timesCallback) {
              request.get('http://localhost:9080/info/multiple-ips/', this.options, function(error, response, body) {
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

              next();
            }.bind(this));
          }.bind(this),
        ], done);
      });

      it('handles ip changes without dropping any connections', function(done) {
        // For a period of time we'll make lots of parallel requests while
        // simultaneously triggering DNS changes.
        //
        // We default to 20 seconds, but allow an environment variable override for
        // much longer tests via the multiLongConnectionDrops grunt task.
        var duration = 20;
        if(process.env.CONNECTION_DROPS_DURATION) {
          duration = parseInt(process.env.CONNECTION_DROPS_DURATION, 10);
        }
        var runTests = true;
        setTimeout(function() { runTests = false; }, duration * 1000);
        this.timeout((duration + 20) * 1000);

        var responseCodes = {};
        var seenLocalInterfaceIps = {};

        async.series([
          function(next) {
            setDnsRecords(['no-drops-during-changes.ooga 1 A 127.0.0.1'], next);
          },
          function(next) {
            waitForResponse('/info/no-drops-during-changes/', { statusCode: 200 }, this.options, next);
          }.bind(this),
          function(next) {
            // Setup 25 parallel tasks to make requests in parallel.
            var tasks = [];
            _.times(25, function() {
              tasks.push(function(parallelCallback) {
                async.whilst(function() { return runTests; }, function(whilstCallback) {
                  request.get('http://localhost:9080/info/no-drops-during-changes/', this.options, function(error, response, body) {
                    should.not.exist(error);
                    response.statusCode.should.eql(200);

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
              next();
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
              setDnsRecords([record], function(error) {
                should.not.exist(error);

                // Change the DNS again in less than a second.
                var again = _.random(0, 1000);
                setTimeout(whilstCallback, again);
              });
            }.bind(this), function() {});
          }.bind(this),
        ], done);
      });

      it('resolves new api backends when they are published', function(done) {
        this.timeout(30000);

        async.series([
          function(next) {
            setDnsRecords(['newly-published-backend.ooga 60 A 127.0.0.2'], next);
          },
          function(next) {
            shared.setDbConfigOverrides({
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
                      frontend_prefix: '/info/newly-published-backend/',
                      backend_prefix: '/info/newly-published-backend/',
                    }
                  ],
                },
              ],
            }, next);
          },
          function(next) {
            shared.waitForConfig(next);
          },
          function(next) {
            waitForResponse('/info/newly-published-backend/', { statusCode: 200, localInterfaceIp: '127.0.0.2' }, this.options, next);
          }.bind(this),
          function(next) {
            // Remove DB-based config after these tests, so the rest of the tests
            // go back to the file-based configs.
            shared.revertDbConfigOverrides(next);
          },
          function(next) {
            shared.waitForConfig(next);
          },
        ], done);
      });
    });

    describe('with stale caching', function() {
      var maxStale = 3;
      shared.runServer({
        dns_resolver: {
          nameservers: [
            '[127.0.0.1]:' + config.get('unbound.port'),
          ],
          max_stale: maxStale,
          negative_ttl: false,
        },
        apis: [
          {
            frontend_host: 'localhost',
            backend_host: 'stale-caching-down-after-ttl-expires.ooga',
            servers: [
              {
                host: 'stale-caching-down-after-ttl-expires.ooga',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/info/stale-caching-down-after-ttl-expires/',
                backend_prefix: '/info/stale-caching-down-after-ttl-expires/',
              },
            ],
          },
        ],
      }, {
        user: { settings: { rate_limit_mode: 'unlimited' } },
      });

      it('takes a host down if it fails to resolve after the TTL expires', function(done) {
        this.timeout(25000);

        var ttl = 4;
        var startTtlCounterTime;
        async.series([
          function(next) {
            setDnsRecords(['stale-caching-down-after-ttl-expires.ooga ' + ttl + ' A 127.0.0.1'], next);
          },
          function(next) {
            waitForResponse('/info/stale-caching-down-after-ttl-expires/', { statusCode: 200, localInterfaceIp: '127.0.0.1' }, this.options, next);
          }.bind(this),
          function(next) {
            startTtlCounterTime = new Date();
            setDnsRecords([], next);
          },
          function(next) {
            waitForResponse('/info/stale-caching-down-after-ttl-expires/', { statusCode: 502 }, this.options, next);
          }.bind(this),
          function(next) {
            var endTtlCounterTime = new Date();
            var duration = endTtlCounterTime - startTtlCounterTime;
            duration.should.be.gte((ttl - TTL_BUFFER + maxStale) * 1000);
            // Double the TTL buffer factor on this test, to account for
            // further fuzziness with the timings of the stale record too.
            duration.should.be.lte((ttl + (TTL_BUFFER * 2) + maxStale) * 1000);
            next();
          },
        ], done);
      });
    });

    describe('with negative caching', function() {
      var negativeTtl = 6;
      shared.runServer({
        dns_resolver: {
          nameservers: [
            '[127.0.0.1]:' + config.get('unbound.port'),
          ],
          max_stale: 0,
          negative_ttl: negativeTtl,
        },
        apis: [
          {
            frontend_host: 'localhost',
            backend_host: 'negative-caching-invalid-hostname-begins-resolving.ooga',
            servers: [
              {
                host: 'negative-caching-invalid-hostname-begins-resolving.ooga',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/info/negative-caching-invalid-hostname-begins-resolving/',
                backend_prefix: '/info/negative-caching-invalid-hostname-begins-resolving/',
              },
            ],
          },
        ],
      }, {
        user: { settings: { rate_limit_mode: 'unlimited' } },
      });

      before(function() {
        // The negative TTL caching really begins as soon as the initial
        // configuration is put into place by runServer (since that's when the
        // hostname is first seen and the unresolvable status is cached). So
        // start our timer here.
        this.startTtlCounterTime = new Date();
      });

      it('brings a host up if a previously invalid hostname begins resolving', function(done) {
        this.timeout(20000);

        async.series([
          function(next) {
            request.get('http://localhost:9080/info/negative-caching-invalid-hostname-begins-resolving/', this.options, function(error, response) {
              should.not.exist(error);
              response.statusCode.should.eql(502);
              next();
            });
          }.bind(this),
          function(next) {
            setDnsRecords(['negative-caching-invalid-hostname-begins-resolving.ooga 60 A 127.0.0.1'], next);
          },
          function(next) {
            waitForResponse('/info/negative-caching-invalid-hostname-begins-resolving/', { statusCode: 200, localInterfaceIp: '127.0.0.1' }, this.options, next);
          }.bind(this),
          function(next) {
            var endTtlCounterTime = new Date();
            var duration = endTtlCounterTime - this.startTtlCounterTime;
            duration.should.be.gte((negativeTtl - TTL_BUFFER) * 1000);
            duration.should.be.lte((negativeTtl + TTL_BUFFER) * 1000);
            next();
          }.bind(this),
        ], done);
      });
    });
  });

  describe('backend ssl certificates', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'sni1.foo.ooga',
          backend_protocol: 'https',
          servers: [
            {
              host: '127.0.0.1',
              port: 9448,
            },
          ],
          url_matches: [
            {
              frontend_prefix: '/sni1/',
              backend_prefix: '/',
            },
          ],
        },
        {
          frontend_host: 'localhost',
          backend_host: 'sni2.foo.ooga',
          backend_protocol: 'https',
          servers: [
            {
              host: '127.0.0.1',
              port: 9448,
            },
          ],
          url_matches: [
            {
              frontend_prefix: '/sni2/',
              backend_prefix: '/',
            },
          ],
        },
      ],
    });

    it('establishes connections to backends that require SNI SSL support', function(done) {
      async.series([
        function(next) {
          setDnsRecords([
            'sni1.foo.ooga 60 A 127.0.0.1',
            'sni2.foo.ooga 60 A 127.0.0.1',
          ], next);
        },
        function(next) {
          // Verify that a non-SNI connection fails completely, rather than
          // returning some default certificate.
          exec('echo "Q" | openssl s_client -connect 127.0.0.1:9448', function(error, stdout) {
            stdout.should.contain('no peer certificate available');
            stdout.should.not.contain('ssltest.example.com');
            next();
          });
        },
        function(next) {
          exec('echo "Q" | openssl s_client -connect 127.0.0.1:9448 -servername sni1.foo.ooga', function(error, stdout) {
            stdout.should.not.contain('no peer certificate available');
            stdout.should.contain('ssltest.example.com');
            next();
          });
        },
        function(next) {
          exec('echo "Q" | openssl s_client -connect 127.0.0.1:9448 -servername sni2.foo.ooga', function(error, stdout) {
            stdout.should.not.contain('no peer certificate available');
            stdout.should.contain('ssltest.example.com');
            next();
          });
        },
        function(next) {
          request.get('http://localhost:9080/sni1/', this.options, function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            response.body.should.eql('SNI1');
            next();
          });
        }.bind(this),
        function(next) {
          request.get('http://localhost:9080/sni2/', this.options, function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            response.body.should.eql('SNI2');
            next();
          });
        }.bind(this),
      ], done);
    });
  });
});
