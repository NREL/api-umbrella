'use strict';

require('../test_helper');

var ipaddr = require('ipaddr.js');

describe('config reloader', function() {
  describe('dns resolver', function() {
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
      ],
    });

    it('resolves server host names', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_example-api_backend {[^}]*}/)[0];
      var upstreamIp = block.match(/server (.+):80;/)[1];

      upstreamIp.should.not.eql('0.0.0.0');
      ipaddr.isValid(upstreamIp).should.eql(true);
    });

    it('leaves ip addresses alone', function() {
      var block = this.nginxConfigContents.match(/upstream api_umbrella_example-ip-api_backend {[^}]*}/)[0];
      var upstreamIp = block.match(/server (.+):80;/)[1];

      upstreamIp.should.eql('8.8.8.8');
    });
  });
});

