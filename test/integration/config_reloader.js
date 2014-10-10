'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    ConfigReloaderWorker = require('../../lib/config_reloader/worker').Worker,
    dns = require('native-dns'),
    DnsResolver = require('../../lib/config_reloader/dns_resolver').DnsResolver,
    ipaddr = require('ipaddr.js'),
    ippp = require('ipplusplus'),
    logger = require('../../lib/logger'),
    moment = require('moment'),
    sinon = require('sinon');

describe('config reloader', function() {
  describe('dns resolver', function() {
    var incrementingIp = '10.10.10.1';
    var alternatingIp = '10.20.20.1';

    // Stub the DNS lookups since these can be unpredictably slow depending on
    // your DNS provider and network connection.
    before(function() {
      this.reloadNginxStub = sinon.stub(ConfigReloaderWorker.prototype, 'reloadNginx', function(writeConfigsCallback) {
        logger.info('Reloading nginx (stub)...');

        if(writeConfigsCallback) {
          writeConfigsCallback(null);
        }
      });

      // Stub the dns.Request send call.
      this.dnsRequestSend = sinon.stub(dns.Request.prototype, 'send', function() {
        var message = {
          answer: [],
        };

        if(this.question.type !== 1) {
          console.error('Unexpected question type for DNS request stub:', this.question.type);
          process.exit(1);
        }

        switch(this.question.name) {
          case 'google.com':
            message.answer = [
              { name: 'google.com',
                type: 1,
                class: 1,
                ttl: 174,
                address: '74.125.228.105' },
              { name: 'google.com',
                type: 1,
                class: 1,
                ttl: 174,
                address: '74.125.228.100' },
              { name: 'google.com',
                type: 1,
                class: 1,
                ttl: 174,
                address: '74.125.228.110' },
            ];

            break;
          case 'example.com':
            message.answer = [
              { name: 'example.com',
                type: 1,
                class: 1,
                ttl: 40138,
                address: '93.184.216.119' },
            ];

            break;
          case 'yahoo.com':
            message.answer = [
              { name: 'yahoo.com',
                type: 1,
                class: 1,
                ttl: 765,
                address: '98.138.253.109' },
              { name: 'yahoo.com',
                type: 1,
                class: 1,
                ttl: 765,
                address: '98.139.183.24' },
              { name: 'yahoo.com',
                type: 1,
                class: 1,
                ttl: 765,
                address: '206.190.36.45' }
            ];

            break;
          case 'www.akamai.com':
            message.answer = [
              { name: 'www.akamai.com',
                type: 5,
                class: 1,
                ttl: 11,
                data: 'wwwsecure.akamai.com.edgekey.net' },
              { name: 'wwwsecure.akamai.com.edgekey.net',
                type: 5,
                class: 1,
                ttl: 312,
                data: 'e8921.dscb.akamaiedge.net' },
              { name: 'e8921.dscb.akamaiedge.net',
                type: 1,
                class: 1,
                ttl: 20,
                address: '23.7.77.233' }
            ];

            break;
          case 'blogs.akamai.com':
            message.answer = [
              { name: 'blogs.akamai.com',
                type: 5,
                class: 1,
                ttl: 300,
                data: 'blogs.akamai.com.edgekey.net' },
              { name: 'blogs.akamai.com.edgekey.net',
                type: 5,
                class: 1,
                ttl: 657,
                data: 'e5246.dscb.akamaiedge.net' },
              { name: 'e5246.dscb.akamaiedge.net',
                type: 1,
                class: 1,
                ttl: 20,
                address: '184.28.63.64' }
            ];

            break;
          case 'api.data.gov':
            message.answer = [
              { name: 'api.data.gov',
                type: 5,
                class: 1,
                ttl: 293,
                data: 'apis-947257526.us-east-1.elb.amazonaws.com' },
              { name: 'apis-947257526.us-east-1.elb.amazonaws.com',
                type: 1,
                class: 1,
                ttl: 60,
                address: '54.84.241.143' },
              { name: 'apis-947257526.us-east-1.elb.amazonaws.com',
                type: 1,
                class: 1,
                ttl: 60,
                address: '54.85.135.143' }
            ];

            break;
          case 'uncached-incrementing.blah':
            incrementingIp = ippp.next(incrementingIp);
            message.answer = [
              { name: 'uncached-incrementing.blah',
                type: 1,
                class: 1,
                ttl: 0.1,
                address: incrementingIp },
            ];

            break;
          case 'uncached-alternating.blah':
            alternatingIp = (alternatingIp === '10.20.20.1') ? '10.20.20.2' : '10.20.20.1';
            message.answer = [
              { name: 'uncached-alternating.blah',
                type: 1,
                class: 1,
                ttl: 0.1,
                address: alternatingIp },
            ];

            break;
          case 'once-valid.akamai.com':
            message.answer = [
              { name: 'foo.akamai.com',
                type: 5,
                class: 1,
                ttl: 300,
                data: 'foo.akamai.com.edgekey.net' },
              { name: 'foo.akamai.com.edgekey.net',
                type: 5,
                class: 1,
                ttl: 657,
                data: 'e5246.dscb.akamaiedge.net' },
            ];

            break;
          case 'localhost':
          case 'once-valid.blah':
          case 'foo.blah':
            message.answer = [];
            break;
          default:
            console.error('Unexpected host for DNS request stub:', this.question.name);
            process.exit(1);
        }

        process.nextTick(function() {
          this.handle(null, message, false);
        }.bind(this));
      });

      // Stub the fallback dns.lookup call.
      this.dnsLookupStub = sinon.stub(dns, 'lookup', function(host, callback) {
        switch(host) {
          case 'localhost':
            callback(null, '127.0.0.1');
            break;
          case 'once-valid.blah':
          case 'once-valid.akamai.com':
          case 'foo.blah':
            callback('Not found');
            break;
          default:
            console.error('Unexpected host for DNS lookup stub:', host);
            process.exit(1);
        }
      });
    });

    after(function() {
      this.reloadNginxStub.restore();
      this.dnsRequestSend.restore();
      this.dnsLookupStub.restore();
    });

    before(function(done) {
      async.parallel([
        function(callback) {
          redisClient.set('router_active_ip:once-valid.blah', '1.2.3.4', callback);
        },
        function(callback) {
          redisClient.set('router_active_ip:www.akamai.com', '10.0.0.1', callback);
        },
        function(callback) {
          redisClient.set('router_active_ip:once-valid.akamai.com', '2.3.4.5', callback);
        },
        function(callback) {
          var key = 'router_seen_ips:once-valid.akamai.com:' + moment().subtract(0, 'hours').format(DnsResolver.RECENT_IP_BUCKET_TIME_FORMAT);
          redisClient.sadd(key, ['3.4.5.6'], callback);
        },
        function(callback) {
          var key = 'router_seen_ips:www.akamai.com:' + moment().subtract(1, 'hours').format(DnsResolver.RECENT_IP_BUCKET_TIME_FORMAT);
          redisClient.sadd(key, ['10.0.0.1'], callback);
        },
        function(callback) {
          redisClient.set('router_active_ip:blogs.akamai.com', '10.0.0.1', callback);
        },
        function(callback) {
          var key = 'router_seen_ips:blogs.akamai.com:' + moment().subtract(2, 'hours').format(DnsResolver.RECENT_IP_BUCKET_TIME_FORMAT);
          redisClient.sadd(key, ['10.0.0.1'], callback);
        },
      ], done);
    });

    shared.runConfigReloader();

    it('resolves server host names', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_config-reloader-example-api_backend {[^}]*}/)[0];
      var ip = block.match(/server (.+):80;/)[1];

      ip.should.not.eql('255.255.255.255');
      ipaddr.isValid(ip).should.eql(true);
    });

    it('leaves ip addresses alone', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_config-reloader-example-ip-api_backend {[^}]*}/)[0];
      var upstreamIp = block.match(/server (.+):80;/)[1];

      upstreamIp.should.eql('8.8.8.8');
    });

    it('resolves unknown hosts to 255.255.255.255', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_config-reloader-invalid-api_backend {[^}]*}/)[0];
      var upstreamIp = block.match(/server (.+):80;/)[1];

      upstreamIp.should.eql('255.255.255.255');
    });

    it('resolves local hostnames (like localhost)', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_config-reloader-localhost-api_backend {[^}]*}/)[0];
      var upstreamIp = block.match(/server (.+):80;/)[1];

      upstreamIp.should.eql('127.0.0.1');
    });

    it('caches the active address in redis', function(done) {
      redisClient.get('router_active_ip:example.com', function(error, ip) {
        ip.should.not.eql('255.255.255.255');
        ipaddr.isValid(ip).should.eql(true);
        done();
      });
    });

    it('maintains a list of recently seen valid ips in redis for cnames that are set to ignore the ttl', function(done) {
      var key = 'router_seen_ips:blogs.akamai.com:' + moment().format(DnsResolver.RECENT_IP_BUCKET_TIME_FORMAT);
      redisClient.smembers(key, function(error, ips) {
        ips.length.should.be.greaterThan(0);
        ipaddr.isValid(ips[0]).should.eql(true);
        done();
      });
    });

    it('maintains a list of recently seen valid ips in redis for domains that are set to ignore the ttl', function(done) {
      var key = 'router_seen_ips:yahoo.com:' + moment().format(DnsResolver.RECENT_IP_BUCKET_TIME_FORMAT);
      redisClient.smembers(key, function(error, ips) {
        ips.length.should.be.greaterThan(0);
        ipaddr.isValid(ips[0]).should.eql(true);
        done();
      });
    });

    it('does not cache recently seen ips by default', function(done) {
      var key = 'router_seen_ips:api.data.gov:' + moment().format(DnsResolver.RECENT_IP_BUCKET_TIME_FORMAT);
      redisClient.smembers(key, function(error, ips) {
        ips.length.should.be.eql(0);
        done();
      });
    });

    it('caches the active address in redis if unresolved', function(done) {
      redisClient.get('router_active_ip:foo.blah', function(error, ip) {
        ip.should.eql('255.255.255.255');
        done();
      });
    });

    it('does not cache unresolved addresses in the list of recently seen valid ips', function(done) {
      var key = 'router_seen_ips:foo.blah:' + moment().format(DnsResolver.RECENT_IP_BUCKET_TIME_FORMAT);
      redisClient.smembers(key, function(error, ips) {
        ips.length.should.eql(0);
        done();
      });
    });

    it('maintains previously cached addresses even if no longer valid', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_config-reloader-once-valid-api_backend {[^}]*}/)[0];
      var upstreamIp = block.match(/server (.+):80;/)[1];

      upstreamIp.should.eql('1.2.3.4');
    });

    it('maintains previously cached addresses for domains that have recently seen ips, but do not currently resolve', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_config-reloader-once-valid-use-recent-api_backend {[^}]*}/)[0];
      var upstreamIp = block.match(/server (.+):80;/)[1];

      upstreamIp.should.eql('2.3.4.5');
    });

    it('keeps using the same address if it has been seen in the past 2 wall hours', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_config-reloader-use-recent-cname-api_backend {[^}]*}/)[0];
      var ip = block.match(/server (.+):80;/)[1];

      ip.should.eql('10.0.0.1');
    });

    it('stops using recently seen address more than 2 wall hours old', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_config-reloader-use-recent-expired-api_backend {[^}]*}/)[0];
      var ip = block.match(/server (.+):80;/)[1];

      ip.should.eql('184.28.63.64');
    });

    it('triggers change events each time the IP changes for uncached hosts', function(done) {
      var i = 0;
      var ips = [];
      this.configReloader.resolver.on('hostChanged', function(host, ip) {
        if(host === 'uncached-incrementing.blah') {
          ips.push(ip);
          i++;

          if(i === 10) {
            ips.length.should.eql(10);
            _.uniq(ips).length.should.eql(10);

            done();
          }
        }
      });
    });

    it('triggers change events even if IPs have recently been seen for uncached hosts', function(done) {
      var i = 0;
      var ips = [];
      this.configReloader.resolver.on('hostChanged', function(host, ip) {
        if(host === 'uncached-alternating.blah') {
          ips.push(ip);
          i++;

          if(i === 10) {
            ips.length.should.eql(10);
            _.uniq(ips).length.should.eql(2);

            done();
          }
        }
      });
    });

    it('triggers an nginx restart when hosts change', function(done) {
      var changeCount = 0;
      var nginxWriteCount = 0;

      this.configReloader.on('nginx', function() {
        nginxWriteCount++;
      });

      this.configReloader.resolver.on('hostChanged', function(host) {
        if(host === 'uncached-incrementing.blah') {
          changeCount++;
          if(changeCount === 2) {
            nginxWriteCount.should.eql(1);
            done();
          }
        }
      });
    });

    it('delays an nginx restart if it has already been restarted recently', function(done) {
      var changeCount = 0;
      var nginxWriteCount = 0;

      this.configReloader.on('nginx', function() {
        nginxWriteCount++;
      });

      this.configReloader.resolver.on('hostChanged', function(host) {
        if(host === 'uncached-incrementing.blah') {
          changeCount++;
          if(changeCount === 10) {
            nginxWriteCount.should.eql(1);
            this.configReloader.hostChangedRestart.should.not.eql(null);
            done();
          }
        }
      });
    });
  });
});
