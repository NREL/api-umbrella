'use strict';

require('../test_helper');

var _ = require('lodash'),
    request = require('request');

describe('url rewrites', function() {
  shared.runServer({
    apis: [
      {
        frontend_host: 'with-apis-and-website.foo',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9444,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/api-example/',
            backend_prefix: '/example/',
          },
        ],
      },
    ],
    website_backends: [
      {
        frontend_host: 'with-apis-and-website.foo',
        server_host: '127.0.0.1',
        server_port: 9444,
      },
    ],
    hosts: [
      {
        hostname: 'default.foo',
        default: true,
        rewrites: [
          '^/admin/rewrite_me$ https://example.com/ permanent',
          '^/hello/rewrite/(debian|el|ubuntu)/([\\d\\.]+)/(file[_-]([\\d\\.]+)-\\d+).*((\\.|_)(amd64|x86_64).(deb|rpm)) https://example.com/downloads/v$4/$3.$1$2$5? redirect',
          '^/hello/rewrite https://example.com/something/ permanent',
        ],
      },
      {
        hostname: 'with-apis-and-website.foo',
        rewrites: [
          '^/api-example/rewrite_me$ https://example.com/ permanent',
          '^/website-example/rewrite_me$ https://2.example.com/ permanent',
        ],
      },
      {
        hostname: 'withweb.foo',
      },
    ],
  });

  beforeEach(function() {
    this.options = {
      followRedirect: false,
      strictSSL: false,
    };
  });

  it('performs simple nginx style rewrites on a per host basis', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'Host': 'default.foo',
      },
    });
    request.get('http://localhost:9080/hello/rewrite?foo=bar', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(301);
      response.headers.location.should.eql('https://example.com/something/?foo=bar');
      done();
    });
  });

  it('performs more complex nginx style rewrites on a per host basis', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'Host': 'default.foo',
      },
    });
    request.get('http://localhost:9080/hello/rewrite/el/7/file-0.6.0-1.el7.x86_64.rpm?foo=bar', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(302);
      response.headers.location.should.eql('https://example.com/downloads/v0.6.0/file-0.6.0-1.el7.x86_64.rpm');
      done();
    });
  });

  it('rewrites take precendence over potential API matches', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'Host': 'with-apis-and-website.foo',
      },
    });
    request.get('http://localhost:9080/api-example/rewrite_me', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(301);
      response.headers.location.should.eql('https://example.com/');

      request.get('http://localhost:9080/api-example/rewrite_me_just_kidding', options, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(403);
        response.headers['content-type'].should.contain('application/json');
        body.should.contain('API_KEY_MISSING');
        done();
      });
    });
  });

  it('rewrites take precendence over potential website matches', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'Host': 'with-apis-and-website.foo',
      },
    });
    request.get('http://localhost:9080/website-example/rewrite_me', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(301);
      response.headers.location.should.eql('https://2.example.com/');

      request.get('http://localhost:9080/website-example/rewrite_me_just_kidding', options, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(404);
        response.headers['content-type'].should.contain('text/html');
        body.should.contain('Test 404 Not Found');
        done();
      });
    });
  });

  it('rewrites take precendence over potential web admin matches', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'Host': 'default.foo',
      },
    });
    request.get('https://localhost:9081/admin/rewrite_me', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(301);
      response.headers.location.should.eql('https://example.com/');

      request.get('https://localhost:9081/admin/rewrite_me_just_kidding', options, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(404);
        response.headers['content-type'].should.contain('text/html');
        body.should.contain('The page you were looking for doesn\'t exist (404)');
        done();
      });
    });
  });

  it('does not perform rewrites on other known hosts', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'Host': 'withweb.foo',
      },
    });
    request.get('http://localhost:9080/hello/rewrite?foo=bar', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(404);
      done();
    });
  });

  it('performs rewrites on unknown hosts if default host is present', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'Host': 'unknown.foo',
      },
    });
    request.get('http://localhost:9080/hello/rewrite?foo=bar', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(301);
      response.headers.location.should.eql('https://example.com/something/?foo=bar');
      done();
    });
  });

  describe('without default host', function() {
    shared.runServer({
      hosts: [
        {
          hostname: 'default.foo',
          rewrites: [
            '^/admin/rewrite_me$ https://example.com/ permanent',
            '^/hello/rewrite/(debian|el|ubuntu)/([\\d\\.]+)/(file[_-]([\\d\\.]+)-\\d+).*((\\.|_)(amd64|x86_64).(deb|rpm)) https://example.com/downloads/v$4/$3.$1$2$5? redirect',
            '^/hello/rewrite https://example.com/something/ permanent',
          ],
        },
      ],
    });

    it('does not perform rewrites on unknown hosts if default host is not present', function(done) {
      var options = _.merge({}, this.options, {
        headers: {
          'Host': 'withweb.foo',
        },
      });
      request.get('http://localhost:9080/hello/rewrite?foo=bar', options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(404);
        done();
      });
    });
  });
});
