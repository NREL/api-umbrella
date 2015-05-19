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
        request.get('http://localhost:9333/headers/?api_key=' + this.apiKey, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['x-add1'].should.eql('test1');
          response.headers['x-add2'].should.eql('test2');
          done();
        });
      });

      it('leaves existing headers (case insensitive)', function(done) {
        request.get('http://localhost:9333/headers/?api_key=' + this.apiKey, function(error, response) {
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
        request.get('http://localhost:9333/headers/sub/?api_key=' + this.apiKey, function(error, response) {
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
        request.get('http://localhost:9333/headers/?api_key=' + this.apiKey, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['x-add1'].should.eql('test1');
          response.headers['x-add2'].should.eql('test2');
          done();
        });
      });

      it('overrides existing headers (case insensitive)', function(done) {
        request.get('http://localhost:9333/headers/?api_key=' + this.apiKey, function(error, response) {
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
        request.get('http://localhost:9333/headers/sub/?api_key=' + this.apiKey, function(error, response) {
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

  describe('rewrites redirects', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/front/end/path',
              backend_prefix: '/backend-prefix'
            }
          ],
          settings: {
            override_response_headers: []
          },
          sub_settings: []
        },
      ],
    });
    describe('RewriteResponse.rewriteRedirects', function() {
      var baseUrl = function(apiKey) { return 'http://localhost:9333/front/end/path/redirect?api_key=' + apiKey; };
      it('does not modify the redirect if it is relative', function(done) {
        request.get(baseUrl(this.apiKey), {followRedirect: false}, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(302);
          response.headers['location'].should.eql('/hello');
          done();
        });
      });
      it('does not modify the redirect if it is absolute, to an unrelated domain', function(done) {
        request.get(baseUrl(this.apiKey) + '&to=' + encodeURIComponent('http://other_url.com/hello'), {followRedirect: false}, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(302);
          response.headers['location'].should.eql('http://other_url.com/hello');
          done();
        });
      });
      it('modifies the redirect if it references the domain', function(done) {
        var apiKey = this.apiKey;
        request.get(baseUrl(apiKey) + '&to=' + encodeURIComponent('http://example.com/hello'), {followRedirect: false}, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(302);
          response.headers['location'].should.eql('http://localhost/hello?api_key=' + apiKey);
          done();
        });
      });
      it('does not override the GET params', function(done) {
        request.get(baseUrl(this.apiKey) + '&to=' + encodeURIComponent('/somewhere?param=example.com'), {followRedirect: false}, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(302);
          response.headers['location'].should.eql('/somewhere?param=example.com');
          done();
        });
      });
      it('only replaces the whole domain', function(done) {
        request.get(baseUrl(this.apiKey) + '&to=' + encodeURIComponent('http://eeexample.com/hello'), {followRedirect: false}, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(302);
          response.headers['location'].should.eql('http://eeexample.com/hello');
          done();
        });
      });
      it('replaces the path', function(done) {
        var apiKey = this.apiKey;
        request.get(baseUrl(apiKey) + '&to=' + encodeURIComponent('http://example.com/backend-prefix/'), {followRedirect: false}, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(302);
          response.headers['location'].should.eql('http://localhost/front/end/path/?api_key=' + apiKey);
          done();
        });
      });
      it('does not interfere with existing GET params', function(done) {
        var apiKey = this.apiKey;
        request.get(baseUrl(apiKey) + '&to=' + encodeURIComponent('http://example.com/?some=param&and=another'), {followRedirect: false}, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(302);
          response.headers['location'].should.eql('http://localhost/?some=param&and=another&api_key=' + apiKey);
          done();
        });
      });
    });
  });
});
