'use strict';

require('../test_helper');

var async = require('async'),
    DnsResolver = require('../../lib/config_reloader/dns_resolver').DnsResolver,
    ipaddr = require('ipaddr.js'),
    moment = require('moment');

describe('config reloader', function() {
  describe('dns resolver', function() {
    before(function(done) {
      async.parallel([
        function(callback) {
          redisClient.set('router_active_ip:once-valid.blah', '1.2.3.4', callback);
        },
        function(callback) {
          redisClient.set('router_active_ip:google.com', '10.0.0.1', callback);
        },
        function(callback) {
          var key = 'router_seen_ips:google.com:' + moment().subtract(3, 'hours').format(DnsResolver.RECENT_IP_BUCKET_TIME_FORMAT);
          redisClient.sadd(key, ['10.0.0.1'], callback);
        },
        function(callback) {
          redisClient.set('router_active_ip:yahoo.com', '10.0.0.1', callback);
        },
        function(callback) {
          var key = 'router_seen_ips:yahoo.com:' + moment().subtract(4, 'hours').format(DnsResolver.RECENT_IP_BUCKET_TIME_FORMAT);
          redisClient.sadd(key, ['10.0.0.1'], callback);
        },
      ], done);
    });

    shared.runConfigReloader({
      apis: [
        {
          _id: 'example-api',
          servers: [
            {
              host: 'example.com',
              port: 80,
            },
          ],
        },
        {
          _id: 'example-ip-api',
          servers: [
            {
              host: '8.8.8.8',
              port: 80,
            },
          ],
        },
        {
          _id: 'invalid-api',
          servers: [
            {
              host: 'foo.blah',
              port: 80,
            },
          ],
        },
        {
          _id: 'once-valid-api',
          servers: [
            {
              host: 'once-valid.blah',
              port: 80,
            },
          ],
        },
        {
          _id: 'cached-api',
          servers: [
            {
              host: 'google.com',
              port: 80,
            },
          ],
        },
        {
          _id: 'localhost-api',
          servers: [
            {
              host: 'localhost',
              port: 80,
            },
          ],
        },
        {
          _id: 'use-recent-api',
          servers: [
            {
              host: 'google.com',
              port: 80,
            },
          ],
        },
        {
          _id: 'recent-expired-api',
          servers: [
            {
              host: 'yahoo.com',
              port: 80,
            },
          ],
        },
      ],
    });

    it('resolves server host names', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_example-api_backend {[^}]*}/)[0];
      var ip = block.match(/server (.+):80;/)[1];

      ip.should.not.eql('255.255.255.255');
      ipaddr.isValid(ip).should.eql(true);
    });

    it('leaves ip addresses alone', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_example-ip-api_backend {[^}]*}/)[0];
      var upstreamIp = block.match(/server (.+):80;/)[1];

      upstreamIp.should.eql('8.8.8.8');
    });

    it('resolves unknown hosts to 255.255.255.255', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_invalid-api_backend {[^}]*}/)[0];
      var upstreamIp = block.match(/server (.+):80;/)[1];

      upstreamIp.should.eql('255.255.255.255');
    });

    it('resolves local hostnames (like localhost)', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_localhost-api_backend {[^}]*}/)[0];
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

    it('maintains a list of recently seen vaid ips in redis', function(done) {
      var key = 'router_seen_ips:example.com:' + moment().format(DnsResolver.RECENT_IP_BUCKET_TIME_FORMAT);
      redisClient.smembers(key, function(error, ips) {
        ips.length.should.be.greaterThan(0);
        ipaddr.isValid(ips[0]).should.eql(true);
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
      var block = this.nginxConfigContents.match(/upstream api_umbrella_once-valid-api_backend {[^}]*}/)[0];
      var upstreamIp = block.match(/server (.+):80;/)[1];

      upstreamIp.should.eql('1.2.3.4');
    });

    it('keeps using the same address if it has been seen in the past 4 wall hours', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_use-recent-api_backend {[^}]*}/)[0];
      var ip = block.match(/server (.+):80;/)[1];

      ip.should.eql('10.0.0.1');
    });

    it('stops using recently seen address more than 4 wall hours old', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_recent-expired-api_backend {[^}]*}/)[0];
      var ip = block.match(/server (.+):80;/)[1];

      ip.should.not.eql('10.0.0.2');
      ip.should.not.eql('255.255.255.255');
      ipaddr.isValid(ip).should.eql(true);
    });
  });
});

