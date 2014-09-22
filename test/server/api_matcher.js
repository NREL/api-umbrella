'use strict';

require('../test_helper');

var request = require('request');

describe('ApiUmbrellaGatekeper', function() {
  describe('api matching', function() {
    describe('host matching', function() {
      shared.runServer({
        apis: [
          {
            'frontend_host': 'localhost:7777',
            'backend_host': 'example.com',
            '_id': 'localhost-non-matching-port',
            'url_matches': [
              {
                'frontend_prefix': '/info/',
                'backend_prefix': '/info/'
              }
            ]
          },
          {
            'frontend_host': 'localhost:9333',
            'backend_host': 'example.com',
            '_id': 'localhost-with-port',
            'url_matches': [
              {
                'frontend_prefix': '/info/',
                'backend_prefix': '/info/'
              }
            ]
          },
          {
            'frontend_host': 'localhost:80',
            'backend_host': 'example.com',
            '_id': 'localhost-default-port',
            'url_matches': [
              {
                'frontend_prefix': '/info/',
                'backend_prefix': '/info/'
              }
            ]
          },
          {
            'frontend_host': 'localhost:443',
            'backend_host': 'example.com',
            '_id': 'localhost-ssl-port',
            'url_matches': [
              {
                'frontend_prefix': '/info/',
                'backend_prefix': '/info/'
              }
            ]
          },
          {
            'frontend_host': 'fallback.example.com',
            'backend_host': 'example.com',
            '_id': 'fallback-no-port',
            'url_matches': [
              {
                'frontend_prefix': '/info/',
                'backend_prefix': '/info/'
              }
            ]
          },
          {
            'frontend_host': 'fallback.example.com:80',
            'backend_host': 'example.com',
            '_id': 'fallback-no-port',
            'url_matches': [
              {
                'frontend_prefix': '/info/',
                'backend_prefix': '/info/'
              }
            ]
          },
        ],
      });

      it('uses full host with port to find the matching api', function(done) {
        var opts = shared.buildRequestOptions('/info/', this.apiKey);
        request.get(opts, function(error, response, body) {
          var data = JSON.parse(body);
          data.headers['x-api-umbrella-backend-id'].should.eql('localhost-with-port');
          done();
        });
      });

      it('prefers the host header', function(done) {
        var opts = shared.buildRequestOptions('/info/', this.apiKey, {
          headers: {
            'Host': 'localhost:80',
          },
        });

        request.get(opts, function(error, response, body) {
          var data = JSON.parse(body);
          data.headers['x-api-umbrella-backend-id'].should.eql('localhost-default-port');
          done();
        });
      });

      it('fills in host headers with missing ports with defaults', function(done) {
        var opts = shared.buildRequestOptions('/info/', this.apiKey, {
          headers: {
            'Host': 'localhost',
          },
        });

        request.get(opts, function(error, response, body) {
          var data = JSON.parse(body);
          data.headers['x-api-umbrella-backend-id'].should.eql('localhost-default-port');
          done();
        });
      });

      it('determines the default ports based on the protocol', function(done) {
        var opts = shared.buildRequestOptions('/info/', this.apiKey, {
          headers: {
            'Host': 'localhost',
            'X-Forwarded-Proto': 'https',
          },
        });

        request.get(opts, function(error, response, body) {
          var data = JSON.parse(body);
          data.headers['x-api-umbrella-backend-id'].should.eql('localhost-ssl-port');
          done();
        });
      });

      it('falls back to the hostname when using a standard port', function(done) {
        var opts = shared.buildRequestOptions('/info/', this.apiKey, {
          headers: {
            'Host': 'fallback.example.com:80',
          },
        });

        request.get(opts, function(error, response, body) {
          var data = JSON.parse(body);
          data.headers['x-api-umbrella-backend-id'].should.eql('fallback-no-port');
          done();
        });
      });

      it('falls back to the hostname when using a non-standard port', function(done) {
        var opts = shared.buildRequestOptions('/info/', this.apiKey, {
          headers: {
            'Host': 'fallback.example.com:123',
          },
        });

        request.get(opts, function(error, response, body) {
          var data = JSON.parse(body);
          data.headers['x-api-umbrella-backend-id'].should.eql('fallback-no-port');
          done();
        });
      });

      describe('non-matching host', function() {
        shared.itBehavesLikeGatekeeperBlocked('/info/', 404, 'NOT_FOUND', {
          headers: {
            'Host': 'unmatched.example.com',
          },
        });
      });
    });

    describe('prefix matching', function() {
      shared.runServer({
        apis: [
          {
            'frontend_host': 'localhost',
            'backend_host': 'example.com',
            '_id': 'other-prefix',
            'url_matches': [
              {
                'frontend_prefix': '/info/other/',
                'backend_prefix': '/info/other/'
              }
            ],
          },
          {
            'frontend_host': 'unused.example.com',
            'backend_host': 'example.com',
            '_id': 'specific-prefix-different-host',
            'url_matches': [
              {
                'frontend_prefix': '/info/specific/',
                'backend_prefix': '/info/specific/'
              }
            ],
          },
          {
            'frontend_host': 'localhost',
            'backend_host': 'example.com',
            '_id': 'specific-prefix',
            'url_matches': [
              {
                'frontend_prefix': '/info/specific/',
                'backend_prefix': '/info/specific/'
              }
            ],
          },
        ],
      });

      it('matches based on host and prefix combination', function(done) {
        var opts = shared.buildRequestOptions('/info/specific/', this.apiKey);
        request.get(opts, function(error, response, body) {
          var data = JSON.parse(body);
          data.headers['x-api-umbrella-backend-id'].should.eql('specific-prefix');
          done();
        });
      });

      it('ignores everything past the matching prefix', function(done) {
        var opts = shared.buildRequestOptions('/info/specific/abc/xyz', this.apiKey);
        request.get(opts, function(error, response, body) {
          var data = JSON.parse(body);
          data.headers['x-api-umbrella-backend-id'].should.eql('specific-prefix');
          done();
        });
      });

      describe('non-matching prefixes', function() {
        describe('mismatched trailing slash', function() {
          shared.itBehavesLikeGatekeeperBlocked('/info/specific', 404, 'NOT_FOUND', {
            headers: {
              'Host': 'unmatched.example.com',
            },
          });
        });
      });
    });

    describe('request rewriting', function() {
      shared.runServer({
        apis: [
          {
            'frontend_host': 'localhost',
            'backend_host': 'example.com',
            '_id': 'rewrites',
            'url_matches': [
              {
                'frontend_prefix': '/info/incoming/',
                'backend_prefix': '/info/outgoing/'
              }
            ],
          },
        ],
      });

      it('rewrites the prefix', function(done) {
        var opts = shared.buildRequestOptions('/info/incoming/example', this.apiKey);
        request.get(opts, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.path.should.eql('/info/outgoing/example');
          done();
        });
      });

      it('maintains query string parameters when rewriting the prefix', function(done) {
        var opts = shared.buildRequestOptions('/info/incoming/example?param1=value1&param2=value2', this.apiKey);
        request.get(opts, function(error, response, body) {
          var data = JSON.parse(body);
          data.url.path.should.eql('/info/outgoing/example?param1=value1&param2=value2');
          done();
        });
      });
    });
  });
});
