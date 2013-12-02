'use strict';

require('../test_helper');

var _ = require('lodash'),
    ProxyLogger = require('../../lib/gatekeeper/logger').Logger,
    sinon = require('sinon');

var spy = sinon.spy(ProxyLogger.prototype, 'push');

describe('request logging', function() {
  shared.runServer();

  function itBehavesLikeALoggedRequest(path, headerOverrides) {
    function headers(scope, overrides) {
      var headersObj = _.extend({
        'X-Api-Key': scope.apiKey,
        'X-Api-Umbrella-Uid': _.uniqueId(),
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

    it('uses the x-api-umbrella-uid header to uniquely identify the request', function(done) {
      var options = { headers: headers(this, headerOverrides) };

      spy.reset();
      request.get('http://localhost:9333' + path, options, function() {
        var call = spy.getCall(0);
        var uid = call.args[0];
        uid.should.eql(options.headers['X-Api-Umbrella-Uid']);
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
          'request_accept_encoding',
          'request_at',
          'request_content_type',
          'request_ip',
          'request_method',
          'request_origin',
          'request_url',
          'request_user_agent',
          'response_age',
          'response_content_encoding',
          'response_content_length',
          'response_content_type',
          'response_server',
          'response_status',
          'response_transfer_encoding',
          'user_email',
          'user_id',
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
          'X-Api-Umbrella-Uid': _.uniqueId(),
        },
      };

      spy.reset();
      request.get('http://localhost:9333/hello?foo=bar&hello', options, function() {
        var call = spy.getCall(0);
        var data = JSON.parse(call.args[2]);

        var date = new Date(data.request_at);
        data.request_at.should.eql(date.toISOString());
        data.request_method.should.eql('GET');
        data.request_url.should.eql('http://localhost:9333/hello?foo=bar&hello');

        data.response_status.should.eql(200);
        data.response_content_length.should.eql(11);
        data.response_content_type.should.eql('text/html; charset=utf-8');

        data.api_key.should.eql(this.apiKey);
        data.user_id.should.eql(this.user._id);
        data.user_email.should.eql(this.user.email);

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
          'X-Api-Umbrella-Uid': _.uniqueId(),
        },
      };

      spy.reset();
      request.get('http://localhost:9333/hello?foo=bar&hello', options, function() {
        var call = spy.getCall(0);
        var data = JSON.parse(call.args[2]);

        var date = new Date(data.request_at);
        data.request_at.should.eql(date.toISOString());
        data.request_method.should.eql('GET');
        data.request_url.should.eql('http://localhost:9333/hello?foo=bar&hello');

        data.response_status.should.eql(403);
        data.response_content_type.should.eql('application/json');

        data.api_key.should.eql('INVALID_KEY');
        should.not.exist(data.user_id);
        should.not.exist(data.user_email);

        data.internal_gatekeeper_time.should.be.a('number');
        should.not.exist(data.internal_response_time);

        done();
      }.bind(this));
    });

  });
});
