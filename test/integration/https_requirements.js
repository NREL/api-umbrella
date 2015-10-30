'use strict';

require('../test_helper');

var _ = require('lodash'),
    Factory = require('factory-lady'),
    request = require('request');

describe('https requirements', function() {
  shared.runServer({
    apis: [
      {
        frontend_host: 'https.foo',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9444,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/info/https/required_return_error/',
            backend_prefix: '/info/',
          },
        ],
        settings: {
          require_https: 'required_return_error',
        },
      },
    ],
  });

  beforeEach(function createUser(done) {
    Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
      this.apiKey = user.api_key;
      this.options = {
        strictSSL: false,
        followRedirect: false,
        headers: {
          'X-Api-Key': this.apiKey,
        },
      };

      done();
    }.bind(this));
  });

  it('returns the https url in the error message', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'Host': 'https.foo',
      },
    });
    request.post('http://localhost:9080/info/https/required_return_error/?foo=bar&test1=test2', options, function(error, response, body) {
      should.not.exist(error);
      response.statusCode.should.eql(400);
      body.should.include('https://https.foo:9081/info/https/required_return_error/?foo=bar&test1=test2');
      done();
    });
  });
});
