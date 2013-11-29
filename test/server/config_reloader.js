'use strict';

require('../test_helper');

var ipaddr = require('ipaddr.js');

describe('config reloader', function() {
  describe('dns resolver', function() {
    before(function(done) {
      redisClient.set('router_active_ip:once-valid.blah', '1.2.3.4', function() {
        redisClient.set('router_active_ip:google.com', '5.6.7.8', function() {
          done();
        });
      });
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
      ],
    });

    it('resolves server host names', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_example-api_backend {[^}]*}/)[0];
      var ip = block.match(/server (.+):80;/)[1];

      ip.should.not.eql('0.0.0.0');
      ipaddr.isValid(ip).should.eql(true);
    });

    it('leaves ip addresses alone', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_example-ip-api_backend {[^}]*}/)[0];
      var upstreamIp = block.match(/server (.+):80;/)[1];

      upstreamIp.should.eql('8.8.8.8');
    });

    it('resolves unknown hosts to 0.0.0.0', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_invalid-api_backend {[^}]*}/)[0];
      var upstreamIp = block.match(/server (.+):80;/)[1];

      upstreamIp.should.eql('0.0.0.0');
    });

    it('caches resolved addresses in redis', function(done) {
      redisClient.get('router_active_ip:example.com', function(error, ip) {
        ip.should.not.eql('0.0.0.0');
        ipaddr.isValid(ip).should.eql(true);
        done();
      });
    });

    it('maintains previously cached addresses even if no longer valid', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_once-valid-api_backend {[^}]*}/)[0];
      var upstreamIp = block.match(/server (.+):80;/)[1];

      upstreamIp.should.eql('1.2.3.4');
    });

    it('replaces the cached values with new values when the domain can be resolved', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_cached-api_backend {[^}]*}/)[0];
      var ip = block.match(/server (.+):80;/)[1];

      ip.should.not.eql('5.6.7.8');
      ip.should.not.eql('0.0.0.0');
      ipaddr.isValid(ip).should.eql(true);
    });
  });
});

