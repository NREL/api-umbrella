'use strict';

require('../test_helper');

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    elasticsearch = require('elasticsearch'),
    Factory = require('factory-lady'),
    path = require('path'),
    request = require('request');

xdescribe('logging', function() {
  before(function truncateElasticsearch(done) {
    this.timeout(5000);

    var config = apiUmbrellaConfig.load(path.resolve(__dirname, '../config/test.yml'));
    this.elasticsearch = new elasticsearch.Client(config.get('elasticsearch'));
    this.elasticsearch.deleteByQuery({
      index: 'api-umbrella-logs-*',
      type: 'log',
      q: '*',
    }, done);
  });

  beforeEach(function(done) {
    this.uniqueId = _.uniqueId();

    Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
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

  it('logs successful requests', function(done) {
    this.timeout(450000);
    request.get('http://localhost:9080/info/connections', this.options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      setTimeout(function() {
        this.elasticsearch.search({
          q: 'api_key:' + this.apiKey,
        }, function(error, response) {
          console.info('ELASTICSEARCH: ', arguments);
          console.info(response);
          console.info(response.hits.hits);

          should.not.exist(error);
          response.hits.total.should.eql(1);
          var record = response.hits.hits[0]._source;
          _.keys(record).sort().should.eql([
            'api_key',
            'backend_response_time',
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
          ]);

          done();
        });
      }.bind(this), 45000);
    }.bind(this));
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
