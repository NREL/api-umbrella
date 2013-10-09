'use strict';

require('../test_helper');

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
});
