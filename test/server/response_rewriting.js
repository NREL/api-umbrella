'use strict';

require('../test_helper');

var request = require('request');

describe('response rewriting', function() {
  describe('setting default response headers', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/',
              backend_prefix: '/',
            }
          ],
          settings: {
            default_response_headers: [
              { key: 'X-Add1', value: 'test1' },
              { key: 'X-Add2', value: 'test2' },
              { key: 'X-Existing1', value: 'test3' },
              { key: 'X-EXISTING2', value: 'test4' },
              { key: 'x-existing3', value: 'test5' },
            ],
          },
          sub_settings: [
            {
              http_method: 'any',
              regex: '^/headers/sub',
              settings: {
                default_response_headers: [
                  { key: 'X-Add2', value: 'overridden' },
                ],
              },
            },
          ],
        },
      ],
    });

    describe('default', function() {
      it('sets new header values', function(done) {
        request.get('http://localhost:9080/headers/?api_key=' + this.apiKey, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['x-add1'].should.eql('test1');
          response.headers['x-add2'].should.eql('test2');
          done();
        });
      });

      it('leaves existing headers (case insensitive)', function(done) {
        request.get('http://localhost:9080/headers/?api_key=' + this.apiKey, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['x-existing1'].should.eql('existing1');
          response.headers['x-existing2'].should.eql('existing2');
          response.headers['x-existing3'].should.eql('existing3');
          done();
        });
      });
    });

    describe('sub-url match', function() {
      it('overrides the default header settings', function(done) {
        request.get('http://localhost:9080/headers/sub/?api_key=' + this.apiKey, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          should.not.exist(response.headers['x-add1']);
          response.headers['x-add2'].should.eql('overridden');
          response.headers['x-existing1'].should.eql('existing1');
          response.headers['x-existing2'].should.eql('existing2');
          response.headers['x-existing3'].should.eql('existing3');
          done();
        });
      });
    });
  });

  describe('setting override response headers', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/',
              backend_prefix: '/',
            }
          ],
          settings: {
            override_response_headers: [
              { key: 'X-Add1', value: 'test1' },
              { key: 'X-Add2', value: 'test2' },
              { key: 'X-Existing1', value: 'test3' },
              { key: 'X-EXISTING2', value: 'test4' },
              { key: 'x-existing3', value: 'test5' },
            ],
          },
          sub_settings: [
            {
              http_method: 'any',
              regex: '^/headers/sub',
              settings: {
                override_response_headers: [
                  { key: 'X-Existing3', value: 'overridden' },
                ],
              },
            },
          ],
        },
      ],
    });

    describe('default', function() {
      it('sets new header values', function(done) {
        request.get('http://localhost:9080/headers/?api_key=' + this.apiKey, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['x-add1'].should.eql('test1');
          response.headers['x-add2'].should.eql('test2');
          done();
        });
      });

      it('overrides existing headers (case insensitive)', function(done) {
        request.get('http://localhost:9080/headers/?api_key=' + this.apiKey, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['x-existing1'].should.eql('test3');
          response.headers['x-existing2'].should.eql('test4');
          response.headers['x-existing3'].should.eql('test5');
          done();
        });
      });
    });

    describe('sub-url match', function() {
      it('overrides the default header settings', function(done) {
        request.get('http://localhost:9080/headers/sub/?api_key=' + this.apiKey, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          should.not.exist(response.headers['x-add1']);
          should.not.exist(response.headers['x-add2']);
          response.headers['x-existing1'].should.eql('existing1');
          response.headers['x-existing2'].should.eql('existing2');
          response.headers['x-existing3'].should.eql('overridden');
          done();
        });
      });
    });
  });
});
