'use strict';

require('../test_helper');

var _ = require('lodash'),
    ProxyLogger = require('../../lib/gatekeeper/logger').Logger,
    request = require('request'),
    sinon = require('sinon');

var spy = sinon.spy(ProxyLogger.prototype, 'push');

describe('request logging', function() {
  shared.runServer();

  function itBehavesLikeALoggedRequest(path, headerOverrides) {
    function headers(scope, overrides) {
      var headersObj = _.extend({
        'X-Api-Key': scope.apiKey,
        'X-Api-Umbrella-Request-ID': _.uniqueId(),
      }, overrides);

      return headersObj;
    }

    it('sends request data for logging', function(done) {
      var options = { headers: headers(this, headerOverrides) };

      spy.reset();
      request.get('http://localhost:9333' + path, options, function() {
        spy.callCount.should.eql(1);
        done();
      });
    });

    it('uses the x-api-umbrella-request-id header to uniquely identify the request', function(done) {
      var options = { headers: headers(this, headerOverrides) };

      spy.reset();
      request.get('http://localhost:9333' + path, options, function() {
        var call = spy.getCall(0);
        var uid = call.args[0];
        uid.should.eql(options.headers['X-Api-Umbrella-Request-ID']);
        done();
      });
    });

    it('indicates that the proxy is the soruce of this log data', function(done) {
      var options = { headers: headers(this, headerOverrides) };

      spy.reset();
      request.get('http://localhost:9333' + path, options, function() {
        var call = spy.getCall(0);
        var source = call.args[1];
        source.should.eql('proxy');
        done();
      });
    });

    it('serializes the expected data as JSON for logging', function(done) {
      var options = { headers: headers(this, headerOverrides) };

      spy.reset();
      request.get('http://localhost:9333' + path, options, function() {
        var call = spy.getCall(0);
        var data = JSON.parse(call.args[2]);

        var knownKeys = [
          'api_key',
          'internal_gatekeeper_time',
          'internal_response_time',
          'request_accept',
          'request_accept_encoding',
          'request_at',
          'request_connection',
          'request_content_type',
          'request_ip',
          'request_method',
          'request_origin',
          'request_url',
          'request_user_agent',
          'request_referer',
          'request_basic_auth_username',
          'response_age',
          'response_content_encoding',
          'response_content_length',
          'response_content_type',
          'response_server',
          'response_status',
          'response_transfer_encoding',
          'user_email',
          'user_id',
          'user_registration_source',
        ];

        var gotKeys = Object.keys(data);

        _.difference(gotKeys, knownKeys).should.eql([]);

        done();
      });
    });
  }

  describe('a valid request', function() {
    itBehavesLikeALoggedRequest('/hello');

    it('contains the expected data', function(done) {
      var options = {
        headers: {
          'X-Api-Key': this.apiKey,
          'X-Api-Umbrella-Request-ID': _.uniqueId(),
          'Accept': 'text/plain',
          'Accept-Encoding': 'gzip,deflate',
          'Connection': 'keep-alive',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Origin': 'http://example.com/',
          'User-Agent': 'curl/7.34.0',
          'Referer': 'http://google.com/',
        },
      };

      spy.reset();
      request.get('http://foo:bar@localhost:9333/hello?foo=bar&hello', options, function() {
        var call = spy.getCall(0);
        var data = JSON.parse(call.args[2]);
        var date = new Date(data.request_at);

        _.omit(data, 'internal_gatekeeper_time', 'internal_response_time').should.eql({
          request_at: date.toISOString(),
          request_method: 'GET',
          request_url: 'http://localhost:9333/hello?foo=bar&hello',
          request_user_agent: 'curl/7.34.0',
          request_accept: 'text/plain',
          request_accept_encoding: 'gzip,deflate',
          request_connection: 'keep-alive',
          request_content_type: 'application/x-www-form-urlencoded',
          request_origin: 'http://example.com/',
          request_referer: 'http://google.com/',
          request_basic_auth_username: 'foo',
          request_ip: '127.0.0.1',
          response_status: 200,
          response_content_length: 11,
          response_content_type: 'text/html; charset=utf-8',
          response_age: null,
          api_key: this.apiKey,
          user_id: this.user._id,
          user_email: this.user.email,
          user_registration_source: this.user.registration_source,
        });

        data.internal_gatekeeper_time.should.be.a('number');
        data.internal_response_time.should.be.a('number');

        done();
      }.bind(this));
    });
  });

  describe('a request generating an api key error', function() {
    itBehavesLikeALoggedRequest('/hello', { 'X-Api-Key': 'INVALID_KEY' });

    it('contains the expected data', function(done) {
      var options = {
        headers: {
          'X-Api-Key': 'INVALID_KEY',
          'X-Api-Umbrella-Request-ID': _.uniqueId(),
        },
      };

      spy.reset();
      request.get('http://localhost:9333/hello?foo=bar&hello', options, function() {
        var call = spy.getCall(0);
        var data = JSON.parse(call.args[2]);
        var date = new Date(data.request_at);

        _.omit(data, 'internal_gatekeeper_time').should.eql({
          request_at: date.toISOString(),
          request_method: 'GET',
          request_url: 'http://localhost:9333/hello?foo=bar&hello',
          request_connection: 'keep-alive',
          request_ip: '127.0.0.1',
          response_status: 403,
          response_content_length: null,
          response_content_type: 'application/json',
          response_age: null,
          api_key: 'INVALID_KEY',
        });

        should.not.exist(data.user_id);
        should.not.exist(data.user_email);

        data.internal_gatekeeper_time.should.be.a('number');
        should.not.exist(data.internal_response_time);

        done();
      }.bind(this));
    });

  });
});
