'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    Factory = require('factory-lady'),
    request = require('request');

describe('logging', function() {
  beforeEach(function(done) {
    this.uniqueQueryId = process.hrtime().join('-') + '-' + Math.random();
    Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
      this.user = user;
      this.apiKey = user.api_key;
      this.options = {
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

  function waitForLog(uniqueQueryId, done) {
    var response;
    async.doWhilst(function(callback) {
      global.elasticsearch.search({
        q: 'request_query.unique_query_id:"' + uniqueQueryId + '"',
      }, function(error, res) {
        if(error) {
          callback(error);
        } else {
          if(res && res.hits && res.hits.total > 0) {
            response = res;
            callback();
          } else {
            setTimeout(callback, 50);
          }
        }
      });
    }, function() {
      return !response;
    }, function(error) {
      response.hits.total.should.eql(1);
      var hit = response.hits.hits[0];
      var record = hit._source;
      done(error, response, hit, record);
    });
  }

  describe('successful requests', function() {
    it('logs all the expected response fileds (for a non-chunked, non-gzipped response)', function(done) {
      this.timeout(45000);

      var options = _.merge({}, this.options, {
        qs: {
          'unique_query_id': this.uniqueQueryId,
        },
        headers: {
          'Accept': 'text/plain; q=0.5, text/html',
          'Accept-Encoding': 'compress, gzip',
          'Connection': 'close',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Origin': 'http://foo.example',
          'User-Agent': 'curl/7.37.1',
          'Referer': 'http://example.com',
        },
        auth: {
          user: 'basic-auth-username-example',
          pass: 'my-secret-password',
        },
      });

      request.get('http://localhost:9080/logging-example/foo/bar/', options, function(error, response) {
        response.statusCode.should.eql(200);

        waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
          var fields = _.keys(record).sort();

          // Varnish randomly turns some non-chunked responses into chunked
          // responses, so this header may crop up, but we'll ignore thit for
          // this test's purposes.
          // See: https://www.varnish-cache.org/trac/ticket/1506
          // TODO: Remove if Varnish changes its behavior.
          fields = _.without(fields, 'response_transfer_encoding');

          fields.should.eql([
            'api_key',
            'backend_response_time',
            'internal_gatekeeper_time',
            'internal_response_time',
            'proxy_overhead',
            'request_accept',
            'request_accept_encoding',
            'request_at',
            'request_basic_auth_username',
            // FIXME: Connection is something we want to log, but it will never
            // get logged, since this gets reset by the router (to force all
            // backend connections to be keep-alived). But we are interested in
            // logging this (so we know what client's support keep alive). We
            // should fix this to log this based on what the front-most router
            // recieves (before it gets reset). We should also look to log HTTP
            // 1.0 vs 1.1 from the front-most connection, so we can also see
            // keepalive support that way.
            //'request_connection',
            'request_content_type',
            'request_hierarchy',
            'request_host',
            'request_ip',
            'request_method',
            'request_origin',
            'request_path',
            'request_query',
            'request_referer',
            'request_scheme',
            'request_size',
            'request_url',
            'request_user_agent',
            'request_user_agent_family',
            'request_user_agent_type',
            'response_age',
            'response_content_length',
            'response_content_type',
            'response_server',
            'response_size',
            'response_status',
            'response_time',
            'user_email',
            'user_id',
            'user_registration_source',
          ]);

          record.api_key.should.eql(this.apiKey);
          (typeof record.backend_response_time).should.eql('number');
          (typeof record.internal_gatekeeper_time).should.eql('number');
          (typeof record.internal_response_time).should.eql('number');
          (typeof record.proxy_overhead).should.eql('number');
          record.request_accept.should.eql('text/plain; q=0.5, text/html');
          record.request_accept_encoding.should.eql('gzip');
          record.request_at.should.match(/^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d\.\d\d\dZ$/);
          record.request_basic_auth_username.should.eql('basic-auth-username-example');
          record.request_content_type.should.eql('application/x-www-form-urlencoded');
          record.request_hierarchy.should.eql([
            '0/localhost/',
            '1/localhost/logging-example/',
            '2/localhost/logging-example/foo/',
            '3/localhost/logging-example/foo/bar',
          ]);
          record.request_host.should.eql('localhost');
          record.request_ip.should.eql('127.0.0.1');
          record.request_method.should.eql('GET');
          record.request_origin.should.eql('http://foo.example');
          record.request_path.should.eql('/logging-example/foo/bar/');
          record.request_query.should.eql({
            'unique_query_id': this.uniqueQueryId,
          });
          record.request_referer.should.eql('http://example.com');
          record.request_scheme.should.eql('http');
          (typeof record.request_size).should.eql('number');
          record.request_url.should.eql('http://localhost:9080/logging-example/foo/bar/?unique_query_id=' + this.uniqueQueryId);
          record.request_user_agent.should.eql('curl/7.37.1');
          record.request_user_agent_family.should.eql('cURL');
          record.request_user_agent_type.should.eql('Library');
          record.response_age.should.eql(20);
          record.response_content_type.should.eql('text/plain; charset=utf-8');
          record.response_server.should.eql('nginx');
          (typeof record.response_size).should.eql('number');
          record.response_status.should.eql(200);
          (typeof record.response_time).should.eql('number');
          record.user_email.should.eql(this.user.email);
          record.user_id.should.eql(this.user.id);
          record.user_registration_source.should.eql('web');

          // Handle the edge-case that Varnish randomly turns non-chunked
          // responses into chunked responses.
          if(record.response_content_length) {
            record.response_content_length.should.eql(5);
          } else {
            record.response_transfer_encoding.should.eql('chunked');
          }

          done();
        }.bind(this));
      }.bind(this));
    });

    it('logs the extra expected fields for chunked or gzip responses', function(done) {
      this.timeout(45000);

      var options = _.merge({}, this.options, {
        gzip: true,
        qs: {
          'unique_query_id': this.uniqueQueryId,
        },
      });

      request.get('http://localhost:9080/compressible-chunked/10/1000', options, function(error, response) {
        response.statusCode.should.eql(200);

        waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
          record.response_content_encoding.should.eql('gzip');
          record.response_transfer_encoding.should.eql('chunked');

          done();
        }.bind(this));
      }.bind(this));
    });
  });

  it('logs requests denied by the gatekeeper', function() {
  });

  it('logs requests when the api backend is down', function() {
  });

  it('logs when the gatekeeper is down', function() {
  });

  it('logs request size', function() {
  });

  it('logs response size', function() {
  });

  describe('request size', function() {
  });

  describe('response size', function() {
  });

  describe('api key', function() {
  });

  describe('request method', function() {
  });

  describe('url scheme', function() {
  });

  describe('url host', function() {
  });

  describe('url path', function() {
  });

  describe('url path hierarchy', function() {
  });

  describe('url query parameters', function() {
  });

  describe('user agent', function() {
  });

  describe('user agent type', function() {
  });

  describe('user agent family', function() {
  });

  describe('api key', function() {
  });

  describe('user id', function() {
  });

  describe('user email', function() {
  });

  describe('user registration source', function() {
  });
});
