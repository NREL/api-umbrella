'use strict';

require('../test_helper');

var _ = require('lodash'),
    request = require('request');

describe('https requirements', function() {
  beforeEach(function(done) {
    Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
      this.apiKey = user.api_key;
      this.options = {
        strictSSL: false,
        followRedirect: false,
        headers: {
          'X-Api-Key': this.apiKey,
          'X-Disable-Router-Connection-Limits': 'yes',
          'X-Disable-Router-Rate-Limits': 'yes',
        },
      };

      done();
    }.bind(this));
  });

  it('https redirects include the original host and URL including api key', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'Host': 'unknown.foo',
      },
    });
    request.get('http://localhost:9080/info/https/required_return_redirect/?foo=bar&test1=test2&api_key=' + this.apiKey, options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(301);
      response.headers.location.should.eql('https://unknown.foo:9081/info/https/required_return_redirect/?foo=bar&test1=test2&api_key=' + this.apiKey);
      done();
    }.bind(this));
  });

  it('POST requests result in a 307 redirect', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'Host': 'unknown.foo',
      },
    });
    request.post('http://localhost:9080/info/https/required_return_redirect/?foo=bar&test1=test2', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(307);
      response.headers.location.should.eql('https://unknown.foo:9081/info/https/required_return_redirect/?foo=bar&test1=test2');
      done();
    });
  });

  it('returns the https url in the error message', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'Host': 'unknown.foo',
      },
    });
    request.post('http://localhost:9080/info/https/required_return_error/?foo=bar&test1=test2', options, function(error, response, body) {
      should.not.exist(error);
      response.statusCode.should.eql(400);
      body.should.include('https://unknown.foo:9081/info/https/required_return_error/?foo=bar&test1=test2');
      done();
    });
  });
});
