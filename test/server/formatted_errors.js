'use strict';

require('../test_helper');

var xml2js = require('xml2js');

describe('formatted error responses', function() {
  describe('format detection', function() {
    shared.runServer();

    it('places the highest priority on the path extension', function(done) {
      var options = { headers: { 'Accept': 'application/json' } };
      request.get('http://localhost:9333/hello.xml?format=json', options, function(error, response, body) {
        body.should.include('<code>API_KEY_MISSING</code>');
        done();
      });
    });

    it('places second highest priority on the format query param', function(done) {
      var options = { headers: { 'Accept': 'application/json' } };
      request.get('http://localhost:9333/hello?format=xml', options, function(error, response, body) {
        body.should.include('<code>API_KEY_MISSING</code>');
        done();
      });
    });

    it('places third highest priority on content negotiation', function(done) {
      var options = { headers: { 'Accept': 'application/json;q=0.5,application/xml;q=0.9' } };
      request.get('http://localhost:9333/hello', options, function(error, response, body) {
        body.should.include('<code>API_KEY_MISSING</code>');
        done();
      });
    });

    it('defaults to JSON when no format is detected', function(done) {
      request.get('http://localhost:9333/hello', function(error, response, body) {
        var data = JSON.parse(body);
        data.error.code.should.eql('API_KEY_MISSING');
        done();
      });
    });

    it('defaults to JSON when an unsupoorted format is detected', function(done) {
      request.get('http://localhost:9333/hello.mov', function(error, response, body) {
        var data = JSON.parse(body);
        data.error.code.should.eql('API_KEY_MISSING');
        done();
      });
    });

    it('defaults to JSON when an unknown format is detected', function(done) {
      request.get('http://localhost:9333/hello.zzz', function(error, response, body) {
        var data = JSON.parse(body);
        data.error.code.should.eql('API_KEY_MISSING');
        done();
      });
    });
  });

  describe('data variables', function() {
    shared.runServer();

    it('substitutes the baseUrl variable', function(done) {
      Factory.create('api_user', { disabled_at: new Date() }, function(user) {
        request.get('http://localhost:9333/hello.json?api_key=' + user.api_key, function(error, response, body) {
          var data = JSON.parse(body);
          data.error.message.should.include(' http://localhost:9333/contact ');
          done();
        });
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
      request.get('http://localhost:9333/hello.json?format=json', function(error, response, body) {
        var validate = function() {
          JSON.parse(body);
        };

        validate.should.not.throw(Error);
        done();
      });
    });

    it('returns valid xml', function(done) {
      request.get('http://localhost:9333/hello.xml?format=json', function(error, response, body) {
        var validate = function() {
          xml2js.parseString(body, { trim: false, strict: true });
        };

        validate.should.not.throw(Error);
        done();
      });
    });

    it('strips leading and trailing whitespace from template', function(done) {
      request.get('http://localhost:9333/hello.xml?format=json', function(error, response, body) {
        body.should.eql('<?xml version="1.0" encoding="UTF-8"?><code>API_KEY_MISSING</code>');
        done();
      });
    });
  });

  describe('api specific templates', function() {
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
              json: '{ "code": {{code}}, "message": {{message}}, "custom": "custom hello", "newvar": {{newvar}} }',
            },
            error_data: {
              api_key_missing: {
                newvar: 'foo',
                message: 'new message',
              },
            },
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
      request.get('http://localhost:9333/custom/hello.json', function(error, response, body) {
        var data = JSON.parse(body);
        data.custom.should.eql('custom hello');
        done();
      });
    });

    it('allows new variables to be set while still inheriting default variables', function(done) {
      request.get('http://localhost:9333/custom/hello.json', function(error, response, body) {
        var data = JSON.parse(body);
        data.newvar.should.eql('foo');
        data.message.should.eql('new message');
        data.code.should.eql('API_KEY_MISSING');
        done();
      });
    });

    it('uses the default error templates if not specified', function(done) {
      request.get('http://localhost:9333/hello.json', function(error, response, body) {
        var data = JSON.parse(body);
        Object.keys(data).should.eql(['error']);
        Object.keys(data.error).sort().should.eql(['code', 'message']);
        done();
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
      request.get('http://localhost:9333/hello.json', function(error, response, body) {
        body.should.eql('{ "unknown":  }');
        done();
      });
    });

    it('doesn\'t die when there are parsing errors in the template', function(done) {
      request.get('http://localhost:9333/hello.xml', function(error, response, body) {
        response.statusCode.should.eql(500);
        body.should.eql('Internal Server Error');
        done();
      });
    });

  });
});
