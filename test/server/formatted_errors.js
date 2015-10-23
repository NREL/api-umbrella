'use strict';

require('../test_helper');

var csv = require('csv'),
    Factory = require('factory-lady'),
    request = require('request'),
    xml2js = require('xml2js');

describe('formatted error responses', function() {
  describe('format detection', function() {
    shared.runServer();

    it('places the highest priority on the path extension', function(done) {
      var options = { headers: { 'Accept': 'application/json' } };
      request.get('http://localhost:9080/hello.xml?format=json', options, function(error, response, body) {
        response.headers['content-type'].should.contain('application/xml');
        body.should.include('<code>API_KEY_MISSING</code>');
        done();
      });
    });

    it('places second highest priority on the format query param', function(done) {
      var options = { headers: { 'Accept': 'application/json' } };
      request.get('http://localhost:9080/hello?format=xml', options, function(error, response, body) {
        response.headers['content-type'].should.contain('application/xml');
        body.should.include('<code>API_KEY_MISSING</code>');
        done();
      });
    });

    it('places third highest priority on content negotiation', function(done) {
      var options = { headers: { 'Accept': 'application/json;q=0.5,application/xml;q=0.9' } };
      request.get('http://localhost:9080/hello', options, function(error, response, body) {
        response.headers['content-type'].should.contain('application/xml');
        body.should.include('<code>API_KEY_MISSING</code>');
        done();
      });
    });

    it('defaults to JSON when no format is detected', function(done) {
      request.get('http://localhost:9080/hello', function(error, response, body) {
        response.headers['content-type'].should.contain('application/json');
        var data = JSON.parse(body);
        data.error.code.should.eql('API_KEY_MISSING');
        done();
      });
    });

    it('defaults to JSON when an unsupoorted format is detected', function(done) {
      request.get('http://localhost:9080/hello.mov', function(error, response, body) {
        response.headers['content-type'].should.contain('application/json');
        var data = JSON.parse(body);
        data.error.code.should.eql('API_KEY_MISSING');
        done();
      });
    });

    it('defaults to JSON when an unknown format is detected', function(done) {
      request.get('http://localhost:9080/hello.zzz', function(error, response, body) {
        response.headers['content-type'].should.contain('application/json');
        var data = JSON.parse(body);
        data.error.code.should.eql('API_KEY_MISSING');
        done();
      });
    });

    it('uses the path extension even if the url contains invalid query params', function(done) {
      var options = { headers: { 'Accept': 'application/json' } };
      request.get('http://localhost:9080/hello.xml?format=json&test=test&url=%ED%A1%BC', options, function(error, response, body) {
        response.headers['content-type'].should.contain('application/xml');
        body.should.include('<code>API_KEY_MISSING</code>');
        done();
      });
    });

    it('gracefully handles query param encoding, format[]=xml', function(done) {
      request.get('http://localhost:9080/hello?format[]=xml', function(error, response, body) {
        response.headers['content-type'].should.contain('application/json');
        var data = JSON.parse(body);
        data.error.code.should.eql('API_KEY_MISSING');
        done();
      });
    });

    it('gracefully handles query param encoding, format=xml&format=csv', function(done) {
      request.get('http://localhost:9080/hello?format=xml&format=csv', function(error, response, body) {
        response.headers['content-type'].should.contain('application/xml');
        body.should.include('<code>API_KEY_MISSING</code>');
        done();
      });
    });

    it('gracefully handles query params encoding, format[key]=value', function(done) {
      request.get('http://localhost:9080/hello?format[key]=value', function(error, response, body) {
        response.headers['content-type'].should.contain('application/json');
        var data = JSON.parse(body);
        data.error.code.should.eql('API_KEY_MISSING');
        done();
      });
    });

    it('gracefully handles query params encoding, format[]=', function(done) {
      request.get('http://localhost:9080/hello?format[]=', function(error, response, body) {
        response.headers['content-type'].should.contain('application/json');
        var data = JSON.parse(body);
        data.error.code.should.eql('API_KEY_MISSING');
        done();
      });
    });

    describe('content negotiation', function() {
      it('supports application/json', function(done) {
        var options = { headers: { 'Accept': 'application/json' } };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          should.not.exist(error);
          response.headers['content-type'].should.contain('application/json');
          var data = JSON.parse(body);
          data.error.code.should.eql('API_KEY_MISSING');
          done();
        });
      });

      it('supports application/xml', function(done) {
        var options = { headers: { 'Accept': 'application/xml' } };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          should.not.exist(error);
          response.headers['content-type'].should.contain('application/xml');
          xml2js.parseString(body, function(error, data) {
            data.response.error[0].code[0].should.eql('API_KEY_MISSING');
            done();
          });
        });
      });

      it('supports text/xml', function(done) {
        var options = { headers: { 'Accept': 'text/xml' } };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          should.not.exist(error);
          response.headers['content-type'].should.contain('text/xml');
          xml2js.parseString(body, function(error, data) {
            data.response.error[0].code[0].should.eql('API_KEY_MISSING');
            done();
          });
        });
      });

      it('supports text/csv', function(done) {
        var options = { headers: { 'Accept': 'text/csv' } };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          should.not.exist(error);
          response.headers['content-type'].should.contain('text/csv');
          csv().from.string(body).to.array(function(data) {
            data[1][0].should.eql('API_KEY_MISSING');
            done();
          });
        });
      });

      it('supports text/html', function(done) {
        var options = { headers: { 'Accept': 'text/html' } };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          should.not.exist(error);
          response.headers['content-type'].should.contain('text/html');
          xml2js.parseString(body, function(error, data) {
            should.not.exist(error);
            data.html.body[0].h1[0].should.eql('API_KEY_MISSING');
            done();
          });
        });
      });

      it('picks the type with the highest quality factor', function(done) {
        var options = { headers: { 'Accept': 'application/json;q=0.5, application/xml;q=0.4, */*;q=0.1, text/csv;q=0.8' } };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          should.not.exist(error);
          response.headers['content-type'].should.contain('text/csv');
          csv().from.string(body).to.array(function(data) {
            data[1][0].should.eql('API_KEY_MISSING');
            done();
          });
        });
      });

      it('picks the first supported type for wildcards', function(done) {
        var options = { headers: { 'Accept': 'application/*;q=0.5, text/*;q=0.6' } };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          should.not.exist(error);
          response.headers['content-type'].should.contain('text/xml');
          xml2js.parseString(body, function(error, data) {
            data.response.error[0].code[0].should.eql('API_KEY_MISSING');
            done();
          });
        });
      });

      it('picks the first type given when nothing else takes precendence', function(done) {
        var options = { headers: { 'Accept': 'text/csv, application/json;q=0.5, application/xml, */*;q=0.1' } };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          should.not.exist(error);
          response.headers['content-type'].should.contain('text/csv');
          csv().from.string(body).to.array(function(data) {
            data[1][0].should.eql('API_KEY_MISSING');
            done();
          });
        });
      });

      it('returns json for unknown type', function(done) {
        var options = { headers: { 'Accept': 'text/foo' } };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          should.not.exist(error);
          response.headers['content-type'].should.contain('application/json');
          var data = JSON.parse(body);
          data.error.code.should.eql('API_KEY_MISSING');
          done();
        });
      });

      it('returns json for wildcard type', function(done) {
        var options = { headers: { 'Accept': '*/*' } };
        request.get('http://localhost:9080/hello', options, function(error, response, body) {
          should.not.exist(error);
          response.headers['content-type'].should.contain('application/json');
          var data = JSON.parse(body);
          data.error.code.should.eql('API_KEY_MISSING');
          done();
        });
      });
    });
  });

  describe('data variables', function() {
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
            error_data: {
              api_key_missing: {
                embedded: 'base_url: {{base_url}} signup_url: {{signup_url}} contact_url: {{contact_url}}',
                embedded_legacy: 'baseUrl: {{baseUrl}} signupUrl: {{signupUrl}} contactUrl: {{contactUrl}}',
              },
            },
            error_templates: {
              json: '{' +
                '"base_url": {{base_url}},' +
                '"baseUrl": {{baseUrl}},' +
                '"signup_url": {{signup_url}},' +
                '"signupUrl": {{signupUrl}},' +
                '"contact_url": {{contact_url}},' +
                '"contactUrl": {{contactUrl}},' +
                '"embedded": {{embedded}},' +
                '"embedded_legacy": {{embedded_legacy}} ' +
              '}',
            },
          },
        },
      ],
    });

    it('substitutes the base_url variable', function(done) {
      request.get('http://localhost:9333/base_url.json', function(error, response, body) {
        var data = JSON.parse(body);
        data.base_url.should.eql('http://localhost:9333');
        done();
      });
    });

    it('substitutes the baseUrl variable', function(done) {
      request.get('http://localhost:9333/baseUrl.json', function(error, response, body) {
        var data = JSON.parse(body);
        data.baseUrl.should.eql('http://localhost:9333');
        done();
      });
    });

    it('substitutes the signup_url variable', function(done) {
      request.get('http://localhost:9333/signup_url.json', function(error, response, body) {
        var data = JSON.parse(body);
        data.signup_url.should.eql('http://localhost:9333');
        done();
      });
    });

    it('substitutes the signupUrl variable', function(done) {
      request.get('http://localhost:9333/signupUrl.json', function(error, response, body) {
        var data = JSON.parse(body);
        data.signupUrl.should.eql('http://localhost:9333');
        done();
      });
    });

    it('substitutes the contact_url variable', function(done) {
      request.get('http://localhost:9333/contact_url.json', function(error, response, body) {
        var data = JSON.parse(body);
        data.contact_url.should.eql('http://localhost:9333/contact/');
        done();
      });
    });

    it('substitutes the contactUrl variable', function(done) {
      request.get('http://localhost:9333/contactUrl.json', function(error, response, body) {
        var data = JSON.parse(body);
        data.contactUrl.should.eql('http://localhost:9333/contact/');
        done();
      });
    });

    it('substitutes variables embedded inside of other variables', function(done) {
      request.get('http://localhost:9333/embedded.json', function(error, response, body) {
        var data = JSON.parse(body);
        data.embedded.should.eql('base_url: http://localhost:9333 signup_url: http://localhost:9333 contact_url: http://localhost:9333/contact/');
        done();
      });
    });

    it('substitutes legacy camel case variables embedded inside of other variables', function(done) {
      request.get('http://localhost:9333/embedded_legacy.json', function(error, response, body) {
        var data = JSON.parse(body);
        data.embedded_legacy.should.eql('baseUrl: http://localhost:9333 signupUrl: http://localhost:9333 contactUrl: http://localhost:9333/contact/');
        done();
      });
    });
  });

  describe('format validation', function() {
    shared.runServer({
      apiSettings: {
        error_templates: {
          json: '\n\n{ "code": {{code}} }\n\n',
          xml: '\n\n   <?xml version="1.0" encoding="UTF-8"?><code>{{code}}</code>\n\n   ',
        },
      },
    });

    it('returns valid json', function(done) {
      request.get('http://localhost:9080/hello.json?format=json', function(error, response, body) {
        response.headers['content-type'].should.contain('application/json');

        var validate = function() {
          JSON.parse(body);
        };

        validate.should.not.throw(Error);
        done();
      });
    });

    it('returns valid xml', function(done) {
      request.get('http://localhost:9080/hello.xml?format=json', function(error, response, body) {
        response.headers['content-type'].should.contain('application/xml');

        var validate = function() {
          xml2js.parseString(body, { trim: false, strict: true });
        };

        validate.should.not.throw(Error);
        done();
      });
    });

    it('strips leading and trailing whitespace from template', function(done) {
      request.get('http://localhost:9080/hello.xml?format=json', function(error, response, body) {
        response.headers['content-type'].should.contain('application/xml');

        body.should.eql('<?xml version="1.0" encoding="UTF-8"?><code>API_KEY_MISSING</code>');
        done();
      });
    });
  });

  describe('api specific templates', function() {
    var escapeTest = '\'"&><,\\';
    shared.runServer({
      apis: [
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/custom/',
              backend_prefix: '/custom/',
            }
          ],
          settings: {
            error_templates: {
              json: '{ "code": {{code}}, "message": {{message}}, "custom": "custom hello", "newvar": {{newvar}}, "escape_test": {{escape_test}} }',
              csv: '{{code}},{{escape_test}}',
              xml: '<?xml version="1.0" encoding="UTF-8"?><escape-test>{{escape_test}}</escape-test>',
              html: '<html><body><h1>{{escape_test}}</h1></body></html>',
            },
            error_data: {
              api_key_missing: {
                newvar: 'foo',
                message: 'new message',
                escape_test: escapeTest,
              },
            },
          },
        },
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/empty/',
              backend_prefix: '/empty/',
            }
          ],
          settings: {
            error_templates: {},
            error_data: {},
          },
        },
        {
          frontend_host: 'localhost',
          backend_host: 'example.com',
          url_matches: [
            {
              frontend_prefix: '/',
              backend_prefix: '/',
            }
          ],
        },
      ],
    });

    it('returns custom error templates', function(done) {
      request.get('http://localhost:9080/custom/hello.json', function(error, response, body) {
        response.headers['content-type'].should.contain('application/json');
        var data = JSON.parse(body);
        data.custom.should.eql('custom hello');
        done();
      });
    });

    it('allows new variables to be set while still inheriting default variables', function(done) {
      request.get('http://localhost:9080/custom/hello.json', function(error, response, body) {
        response.headers['content-type'].should.contain('application/json');
        var data = JSON.parse(body);
        data.newvar.should.eql('foo');
        data.message.should.eql('new message');
        data.code.should.eql('API_KEY_MISSING');
        done();
      });
    });

    it('properly escapes json values', function(done) {
      request.get('http://localhost:9080/custom/hello.json', function(error, response, body) {
        response.headers['content-type'].should.contain('application/json');
        should.not.exist(error);
        var data = JSON.parse(body);
        data.escape_test.should.eql(escapeTest);
        done();
      });
    });

    it('properly escapes xml values', function(done) {
      request.get('http://localhost:9080/custom/hello.xml', function(error, response, body) {
        should.not.exist(error);
        response.headers['content-type'].should.contain('application/xml');
        xml2js.parseString(body, function(error, data) {
          should.not.exist(error);
          data['escape-test'].should.eql(escapeTest);
          done();
        });
      });
    });

    it('properly escapes csv values', function(done) {
      request.get('http://localhost:9080/custom/hello.csv', function(error, response, body) {
        should.not.exist(error);
        response.headers['content-type'].should.contain('text/csv');
        csv().from.string(body).to.array(function(data) {
          data[0][1].should.eql(escapeTest);
          done();
        });
      });
    });

    it('properly escapes html values', function(done) {
      request.get('http://localhost:9080/custom/hello.html', function(error, response, body) {
        should.not.exist(error);
        response.headers['content-type'].should.contain('text/html');
        xml2js.parseString(body, function(error, data) {
          should.not.exist(error);
          data.html.body[0].h1[0].should.eql(escapeTest);
          done();
        });
      });
    });

    it('uses the default error templates if custom error templates and data are set to an empty object', function(done) {
      request.get('http://localhost:9080/empty/hello.json', function(error, response, body) {
        response.headers['content-type'].should.contain('application/json');
        var data = JSON.parse(body);
        Object.keys(data).should.eql(['error']);
        Object.keys(data.error).sort().should.eql(['code', 'message']);
        data.error.code.should.eql('API_KEY_MISSING');
        done();
      });
    });

    it('uses the default error templates if not specified', function(done) {
      request.get('http://localhost:9080/hello.json', function(error, response, body) {
        response.headers['content-type'].should.contain('application/json');
        var data = JSON.parse(body);
        Object.keys(data).should.eql(['error']);
        Object.keys(data.error).sort().should.eql(['code', 'message']);
        data.error.code.should.eql('API_KEY_MISSING');
        done();
      });
    });
  });

  describe('invalid data', function() {
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
            error_data: {
              api_key_missing: 'Foo',
              api_key_invalid: 9,
              api_key_unauthorized: ['foo'],
              api_key_disabled: null,
            },
          },
          sub_settings: [
            {
              http_method: 'any',
              regex: '^/private',
              settings: {
                required_roles: ['private'],
              },
            },
          ],
        },
      ],
    });

    it('returns internal error when error data is unexpectedly a string', function(done) {
      request.get('http://localhost:9080/hello.json', function(error, response, body) {
        response.statusCode.should.eql(500);
        response.headers['content-type'].should.contain('application/json');
        var data = JSON.parse(body);
        data.error.code.should.eql('INTERNAL_SERVER_ERROR');
        done();
      });
    });

    it('returns internal error when error data is unexpectedly a number', function(done) {
      request.get('http://localhost:9080/hello.json?api_key=invalid-key', function(error, response, body) {
        response.statusCode.should.eql(500);
        response.headers['content-type'].should.contain('application/json');
        var data = JSON.parse(body);
        data.error.code.should.eql('INTERNAL_SERVER_ERROR');
        done();
      });
    });

    it('returns internal error when error data is unexpectedly an array', function(done) {
      request.get('http://localhost:9080/private.json?api_key=' + this.apiKey, function(error, response, body) {
        response.statusCode.should.eql(500);
        response.headers['content-type'].should.contain('application/json');
        var data = JSON.parse(body);
        data.error.code.should.eql('INTERNAL_SERVER_ERROR');
        done();
      });
    });

    it('returns default error data when the error data is null', function(done) {
      Factory.create('api_user', { disabled_at: new Date() }, function(user) {
        request.get('http://localhost:9080/hello.json?api_key=' + user.api_key, function(error, response, body) {
          response.statusCode.should.eql(403);
          response.headers['content-type'].should.contain('application/json');
          var data = JSON.parse(body);
          data.error.code.should.eql('API_KEY_DISABLED');
          done();
        });
      });
    });
  });

  describe('invalid templates', function() {
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
            error_templates: {
              json: '{ "unknown": {{bogusvar}} }',
              xml: '<invalid>{{oops}</invalid>',
            },
            error_data: {
              api_key_missing: {
                newvar: 'foo',
                message: 'new message',
              },
            },
          },
        },
      ],
    });

    it('returns empty space when variables are undefined', function(done) {
      request.get('http://localhost:9080/hello.json', function(error, response, body) {
        response.headers['content-type'].should.contain('application/json');
        body.should.eql('{ "unknown":  }');
        done();
      });
    });

    it('doesn\'t die when there are parsing errors in the template', function(done) {
      request.get('http://localhost:9080/hello.xml', function(error, response, body) {
        response.statusCode.should.eql(500);
        response.headers['content-type'].should.contain('text/plain');
        body.should.eql('Internal Server Error');
        done();
      });
    });
  });
});
