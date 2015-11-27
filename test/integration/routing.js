'use strict';

require('../test_helper');

var _ = require('lodash'),
    Factory = require('factory-lady'),
    path = require('path'),
    request = require('request');

describe('routing', function() {
  before(function createAdmin(done) {
    Factory.create('admin', function(admin) {
      this.adminToken = admin.authentication_token;
      done();
    }.bind(this));
  });

  beforeEach(function setDefaultOptions() {
    this.optionsOverrides = {
      strictSSL: false,
      headers: {
        'X-Api-Key': null,
      },
    };
  });

  describe('web admin', function() {
    describe('web app host default wildcard', function() {
      shared.runServer();

      it('routes to the admin app', function(done) {
        this.timeout(5000);
        request.get('https://localhost:9081/admin/login', this.options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Admin Login');
          done();
        });
      });

      it('routes to the admin app for unknown hosts', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
          },
        });
        request.get('https://localhost:9081/admin/login', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Admin Login');
          done();
        });
      });

      it('redirects to https for the admin', function(done) {
        var options = _.merge({}, this.options, {
          followRedirect: false,
          headers: {
            'Host': 'default.foo',
          },
        });
        request.get('http://localhost:9080/admin/login', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(301);
          response.headers.location.should.eql('https://default.foo:9081/admin/login');
          done();
        });
      });

      it('redirects to the same host when performing the https redirect for the admin', function(done) {
        var options = _.merge({}, this.options, {
          followRedirect: false,
          headers: {
            'Host': 'unknown.foo',
          },
        });
        request.get('http://localhost:9080/admin/login', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(301);
          response.headers.location.should.eql('https://unknown.foo:9081/admin/login');
          done();
        });
      });

      it('redirects to the same host when performing the login redirect for the admin', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          followRedirect: false,
          headers: {
            'Host': 'unknown.foo',
          },
        });
        request.get('https://localhost:9081/admin/', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(302);
          response.headers.location.should.eql('https://unknown.foo:9081/admin/login');
          done();
        });
      });
    });

    describe('web app host explicitly defined', function() {
      shared.runServer({
        router: {
          web_app_host: '127.0.0.1',
        },
      });

      it('routes to the admin app for the defined host', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': '127.0.0.1',
          },
        });
        request.get('https://localhost:9081/admin/login', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Admin Login');
          done();
        });
      });

      it('does not route to the admin app for unknown hosts', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
          },
        });
        request.get('https://localhost:9081/admin/login', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(404);
          done();
        });
      });
    });

    describe('conflicting api prefix', function() {
      shared.runServer({
        apis: [
          {
            frontend_host: 'localhost',
            backend_host: 'localhost',
            servers: [
              {
                host: '127.0.0.1',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/admin/',
                backend_prefix: '/info/',
              },
            ],
          },
        ],
      });

      it('gives precedence to the admin app over apis prefixes', function(done) {
        this.timeout(5000);
        request.get('https://localhost:9081/admin/login', this.options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Admin Login');
          done();
        });
      });
    });
  });

  describe('website backends', function() {
    describe('web app host default wildcard', function() {
      shared.runServer({
        apis: [
          {
            frontend_host: 'with-apis-no-website.foo',
            backend_host: 'localhost',
            servers: [
              {
                host: '127.0.0.1',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/example2/',
                backend_prefix: '/info/',
              },
            ],
          },
        ],
        website_backends: [
          {
            frontend_host: 'website.foo',
            server_host: '127.0.0.1',
            server_port: 9443,
          },
        ],
      });

      it('routes to the default static website', function(done) {
        request.get('http://localhost:9080/', this.options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Your API Site Name');

          request.get('https://localhost:9081/signup/', this.options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(200);
            body.should.contain('API Key Signup');
            done();
          });
        }.bind(this));
      });

      it('routes to a custom website backend when it is defined for a specific hostname', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'website.foo',
          },
        });
        request.get('http://localhost:9080/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Test Website Home Page');
          done();
        });
      });

      it('routes to the website backend for any url path not matched by the apis or web admin', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'website.foo',
          },
        });
        request.get('http://localhost:9080/sjkdlfjksdlfj', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(404);
          body.should.contain('Test Website 404 Not Found');
          done();
        });
      });

      it('routes to the default static website for unknown hosts that have no website or apis', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
          },
        });
        request.get('http://localhost:9080/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Your API Site Name');
          done();
        });
      });

      it('routes to the default static website for hosts that have apis but no website', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'with-apis-no-website.foo',
          },
        });
        request.get('http://localhost:9080/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Your API Site Name');

          request.get('http://localhost:9080/example2/', options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(403);
            body.should.contain('API_KEY_MISSING');

            done();
          });
        });
      });

      it('redirects to https for the signup page by default', function(done) {
        var options = _.merge({}, this.options, {
          followRedirect: false,
          headers: {
            'Host': 'default.foo',
          },
        });
        request.get('http://localhost:9080/signup', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(301);
          response.headers.location.should.eql('https://default.foo:9081/signup');
          done();
        });
      });
    });

    describe('web app host explicitly defined', function() {
      shared.runServer({
        apis: [
          {
            frontend_host: 'with-apis-no-website.foo',
            backend_host: 'localhost',
            servers: [
              {
                host: '127.0.0.1',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/example2/',
                backend_prefix: '/info/',
              },
            ],
          },
        ],
        router: {
          web_app_host: '127.0.0.1',
        },
      });

      it('routes to the default static website for the defined host', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': '127.0.0.1',
          },
        });
        request.get('http://localhost:9080/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Your API Site Name');
          done();
        }.bind(this));
      });

      it('returns the api umbrella 404 for unknown hosts that have no website or apis', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
          },
        });
        request.get('http://localhost:9080/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(404);
          response.headers['content-type'].should.contain('application/json');
          body.should.contain('NOT_FOUND');
          done();
        });
      });

      it('returns the api umbrella 404 for hosts that have apis but no website', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'with-apis-no-website.foo',
          },
        });
        request.get('http://localhost:9080/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(404);
          response.headers['content-type'].should.contain('application/json');
          body.should.contain('NOT_FOUND');

          request.get('http://localhost:9080/example2/', options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(403);
            body.should.contain('API_KEY_MISSING');

            done();
          });
        });
      });
    });

    describe('web app host default wildcard and default host set', function() {
      shared.runServer({
        apis: [
          {
            frontend_host: 'with-apis-no-website.foo',
            backend_host: 'localhost',
            servers: [
              {
                host: '127.0.0.1',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/example2/',
                backend_prefix: '/info/',
              },
            ],
          },
        ],
        website_backends: [
          {
            frontend_host: 'website.foo',
            server_host: '127.0.0.1',
            server_port: 9443,
          },
        ],
        hosts: [
          {
            hostname: 'website.foo',
            default: true,
          },
        ],
      });

      it('routes to the default static website', function(done) {
        request.get('http://localhost:9080/', this.options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Your API Site Name');
          done();
        }.bind(this));
      });

      it('routes to a custom website backend when it is defined for a specific hostname', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'website.foo',
          },
        });
        request.get('http://localhost:9080/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Test Website Home Page');
          done();
        });
      });

      it('routes to the website backend for any url path not matched by the apis or web admin', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'website.foo',
          },
        });
        request.get('http://localhost:9080/sjkdlfjksdlfj', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(404);
          body.should.contain('Test Website 404 Not Found');
          done();
        });
      });

      it('routes to the default static website for unknown hosts that have no website or apis', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
          },
        });
        request.get('http://localhost:9080/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Your API Site Name');
          done();
        });
      });

      it('routes to the default static website for hosts that have apis but no website', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'with-apis-no-website.foo',
          },
        });
        request.get('http://localhost:9080/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Your API Site Name');

          request.get('http://localhost:9080/example2/', options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(403);
            body.should.contain('API_KEY_MISSING');

            done();
          });
        });
      });

    });

    describe('web app host explicitly defined and default host set', function() {
      shared.runServer({
        apis: [
          {
            frontend_host: 'with-apis-no-website.foo',
            backend_host: 'localhost',
            servers: [
              {
                host: '127.0.0.1',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/example2/',
                backend_prefix: '/info/',
              },
            ],
          },
        ],
        website_backends: [
          {
            frontend_host: 'website.foo',
            server_host: '127.0.0.1',
            server_port: 9443,
          },
        ],
        router: {
          web_app_host: '127.0.0.1',
        },
        hosts: [
          {
            hostname: 'website.foo',
            default: true,
          },
        ],
      });

      it('routes to the website backend set by the default host', function(done) {
        request.get('http://localhost:9080/', this.options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Test Website Home Page');
          done();
        }.bind(this));
      });

      it('routes to a custom website backend when it is defined for a specific hostname', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'website.foo',
          },
        });
        request.get('http://localhost:9080/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Test Website Home Page');
          done();
        });
      });

      it('routes to the website backend for any url path not matched by the apis or web admin', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'website.foo',
          },
        });
        request.get('http://localhost:9080/sjkdlfjksdlfj', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(404);
          body.should.contain('Test Website 404 Not Found');
          done();
        });
      });

      it('routes to the website backend set by the default host for unknown hosts that have no website or apis', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
          },
        });
        request.get('http://localhost:9080/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Test Website Home Page');
          done();
        });
      });

      it('routes to the website backend set by the default host for hosts that have apis but no website', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'with-apis-no-website.foo',
          },
        });
        request.get('http://localhost:9080/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Test Website Home Page');

          request.get('http://localhost:9080/example2/', options, function(error, response, body) {
            should.not.exist(error);
            response.statusCode.should.eql(403);
            body.should.contain('API_KEY_MISSING');

            done();
          });
        });
      });
    });
  });

  describe('api backends', function() {
    describe('web app host default wildcard', function() {
      shared.runServer({
        apis: [
          {
            frontend_host: 'apis.foo',
            backend_host: 'localhost',
            servers: [
              {
                host: '127.0.0.1',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/hello/',
                backend_prefix: '/hello/',
              },
            ],
          },
        ],
      });

      it('routes to the internal gatekeeper apis', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/state.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('routes to the internal gatekeeper apis for unknown hosts', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/state.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('routes to the internal web app apis', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/users.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('routes to the internal web app apis for unknown hosts', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/users.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('routes to configured apis for a given host', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'apis.foo',
            'X-Api-Key': this.apiKey,
          },
        });
        request.get('https://localhost:9081/hello/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.eql('Hello World');
          done();
        });
      });

      it('does not route to configured apis for unknown hosts', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
            'X-Api-Key': this.apiKey,
          },
        });
        request.get('https://localhost:9081/hello/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(404);
          response.headers['content-type'].should.contain('text/html');
          body.should.contain('nginx');
          done();
        });
      });

      it('does not impact routing to the admin', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': '127.0.0.1',
          },
        });
        request.get('https://localhost:9081/admin/login', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Admin Login');

          options.headers['Host'] = 'unknown.foo';
          request.get('https://localhost:9081/admin/login', options, function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(200);

            done();
          });
        });
      });
    });

    describe('web app host explicitly defined', function() {
      shared.runServer({
        apis: [
          {
            frontend_host: 'apis.foo',
            backend_host: 'localhost',
            servers: [
              {
                host: '127.0.0.1',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/hello/',
                backend_prefix: '/hello/',
              },
            ],
          },
        ],
        router: {
          web_app_host: '127.0.0.1',
        },
      });

      it('routes to the internal gatekeeper apis for the defined host', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': '127.0.0.1',
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/state.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('does not route to the internal gatekeeper apis for unknown hosts', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/state.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(404);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('routes to the internal web app apis for the defined host', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': '127.0.0.1',
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/users.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('does not route to the internal web app apis for unknown hosts', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/users.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(404);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('routes to configured apis for a given host', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'apis.foo',
            'X-Api-Key': this.apiKey,
          },
        });
        request.get('https://localhost:9081/hello/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.eql('Hello World');
          done();
        });
      });

      it('does not route to configured apis for unknown hosts', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
            'X-Api-Key': this.apiKey,
          },
        });
        request.get('https://localhost:9081/hello/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(404);
          response.headers['content-type'].should.contain('application/json');
          body.should.contain('NOT_FOUND');
          done();
        });
      });

      it('does not impact routing to the admin', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': '127.0.0.1',
          },
        });
        request.get('https://localhost:9081/admin/login', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Admin Login');

          options.headers['Host'] = 'unknown.foo';
          request.get('https://localhost:9081/admin/login', options, function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(404);

            done();
          });
        });
      });
    });

    describe('web app host default wildcard and default host set', function() {
      shared.runServer({
        apis: [
          {
            frontend_host: 'apis.foo',
            backend_host: 'localhost',
            servers: [
              {
                host: '127.0.0.1',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/hello/',
                backend_prefix: '/hello/',
              },
            ],
          },
          {
            frontend_host: 'other.foo',
            backend_host: 'localhost',
            servers: [
              {
                host: '127.0.0.1',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/hello/',
                backend_prefix: '/info/other/',
              },
            ],
          },
        ],
        hosts: [
          {
            hostname: 'apis.foo',
            default: true,
          },
        ],
      });

      it('routes to the internal gatekeeper apis', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/state.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('routes to the internal gatekeeper apis for unknown hosts', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/state.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('routes to the internal web app apis', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/users.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('routes to the internal web app apis for unknown hosts', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/users.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('routes to configured apis for a given host', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'apis.foo',
            'X-Api-Key': this.apiKey,
          },
        });
        request.get('https://localhost:9081/hello/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.eql('Hello World');
          done();
        });
      });

      it('routes to the default host apis for unknown hosts', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
            'X-Api-Key': this.apiKey,
          },
        });
        request.get('https://localhost:9081/hello/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.eql('Hello World');
          done();
        });
      });

      it('does not impact routing to the admin', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': '127.0.0.1',
          },
        });
        request.get('https://localhost:9081/admin/login', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Admin Login');

          options.headers['Host'] = 'unknown.foo';
          request.get('https://localhost:9081/admin/login', options, function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(200);

            done();
          });
        });
      });

      it('prefers the apis matching the hostname before the default hostname', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'other.foo',
            'X-Api-Key': this.apiKey,
          },
        });
        request.get('https://localhost:9081/hello/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.url.path.should.eql('/info/other/');
          done();
        });
      });
    });

    describe('web app host explicitly defined and default host set', function() {
      shared.runServer({
        apis: [
          {
            frontend_host: 'apis.foo',
            backend_host: 'localhost',
            servers: [
              {
                host: '127.0.0.1',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/hello/',
                backend_prefix: '/hello/',
              },
            ],
          },
          {
            frontend_host: 'other.foo',
            backend_host: 'localhost',
            servers: [
              {
                host: '127.0.0.1',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/hello/',
                backend_prefix: '/info/other/',
              },
            ],
          },
        ],
        router: {
          web_app_host: '127.0.0.1',
        },
        hosts: [
          {
            hostname: 'apis.foo',
            default: true,
          },
        ],
      });

      it('routes to the internal gatekeeper apis for the defined host', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': '127.0.0.1',
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/state.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('does not route to the internal gatekeeper apis for unknown hosts', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/state.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(404);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('routes to the internal web app apis for the defined host', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': '127.0.0.1',
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/users.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('does not route to the internal web app apis for unknown hosts', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
            'X-Api-Key': this.apiKey,
            'X-Admin-Auth-Token': this.adminToken,
          },
        });
        request.get('https://localhost:9081/api-umbrella/v1/users.json', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(404);
          response.headers['content-type'].should.contain('application/json');
          done();
        });
      });

      it('routes to configured apis for a given host', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'apis.foo',
            'X-Api-Key': this.apiKey,
          },
        });
        request.get('https://localhost:9081/hello/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.eql('Hello World');
          done();
        });
      });

      it('routes to the default host apis for unknown hosts', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'unknown.foo',
            'X-Api-Key': this.apiKey,
          },
        });
        request.get('https://localhost:9081/hello/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.eql('Hello World');
          done();
        });
      });

      it('does not impact routing to the admin', function(done) {
        var options = _.merge({}, this.options, {
          headers: {
            'Host': '127.0.0.1',
          },
        });
        request.get('https://localhost:9081/admin/login', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          body.should.contain('Admin Login');

          options.headers['Host'] = 'unknown.foo';
          request.get('https://localhost:9081/admin/login', options, function(error, response) {
            should.not.exist(error);
            response.statusCode.should.eql(404);

            done();
          });
        });
      });

      it('prefers the apis matching the hostname before the default hostname', function(done) {
        this.timeout(5000);
        var options = _.merge({}, this.options, {
          headers: {
            'Host': 'other.foo',
            'X-Api-Key': this.apiKey,
          },
        });
        request.get('https://localhost:9081/hello/', options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.url.path.should.eql('/info/other/');
          done();
        });
      });
    });

    describe('conflicting api prefix', function() {
      shared.runServer({
        apis: [
          {
            frontend_host: 'localhost',
            backend_host: 'localhost',
            servers: [
              {
                host: '127.0.0.1',
                port: 9444,
              },
            ],
            url_matches: [
              {
                frontend_prefix: '/api-umbrella/',
                backend_prefix: '/info/',
              },
            ],
          },
        ],
      });

      it('gives precedence to the internal apis over other apis', function(done) {
        this.timeout(5000);
        request.get('https://localhost:9081/api-umbrella/v1/state.json', this.options, function(error, response, body) {
          should.not.exist(error);
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          should.exist(data.db_config_version);
          done();
        });
      });
    });
  });

  describe('host ssl certificates', function() {
    shared.runServer({
      hosts: [
        {
          hostname: 'ssl.foo',
          ssl_cert: path.resolve(__dirname, '../config/ssl_test.crt'),
          ssl_cert_key: path.resolve(__dirname, '../config/ssl_test.key'),
        },
      ],
    });

    it('returns the internal, self-signed certificate by default', function(done) {
      request.get('https://localhost:9081/', this.options, function(error, response, body) {
        should.not.exist(error);
        var cert = response.socket.getPeerCertificate();
        cert.subject.should.eql({ O: 'API Umbrella', CN: 'apiumbrella.example.com' });
        done();
      });
    });

    it('returns the internal, self-signed certificate for unknown hosts', function(done) {
      var options = _.merge({}, this.options, {
        headers: {
          'Host': 'unknown.foo',
        },
      });
      request.get('https://localhost:9081/', options, function(error, response, body) {
        should.not.exist(error);
        var cert = response.socket.getPeerCertificate();
        cert.subject.should.eql({ O: 'API Umbrella', CN: 'apiumbrella.example.com' });
        done();
      });
    });

    it('uses SNI to return other certs configured on other domains', function(done) {
      var options = _.merge({}, this.options, {
        headers: {
          'Host': 'ssl.foo',
        },
      });
      request.get('https://localhost:9081/', options, function(error, response, body) {
        should.not.exist(error);
        var cert = response.socket.getPeerCertificate();
        cert.subject.should.eql({ O: 'API Umbrella', CN: 'ssltest.example.com' });
        done();
      });
    });
  });
});
