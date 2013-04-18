require('../test_helper');

describe('ApiUmbrellaGatekeper', function() {
  shared.runServer();

  describe('api key validation', function() {
    describe('no api key supplied', function() {
      beforeEach(function() {
        this.apiKey = null;
      });

      shared.itBehavesLikeGatekeeperBlocked('/hello', 403, 'No api_key was supplied.');
    });

    describe('empty api key supplied', function() {
      beforeEach(function() {
        this.apiKey = '';
      });

      shared.itBehavesLikeGatekeeperBlocked('/hello', 403, 'No api_key was supplied.');
    });

    describe('invalid api key supplied', function() {
      beforeEach(function() {
        this.apiKey = 'invalid';
      });

      shared.itBehavesLikeGatekeeperBlocked('/hello', 403, 'An invalid api_key was supplied.');
    });

    describe('valid api key supplied', function() {
      it('calls the target app', function(done) {
        request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
          backendCalled.should.eql(true);
          response.statusCode.should.eql(200);
          body.should.eql("Hello World");
          done();
        });
      });

      it('looks for the api key in the X-Api-Key header', function(done) {
        request.get('http://localhost:9333/hello', { headers: { 'X-Api-Key': this.apiKey } }, function(error, response, body) {
          body.should.eql("Hello World");
          done();
        });
      });

      it("looks for the api key as a GET parameter", function(done) {
        request.get('http://localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
          body.should.eql("Hello World");
          done();
        });
      });

      it('looks for the api key inside the username of basic auth', function(done) {
        request.get('http://' + this.apiKey + ':@localhost:9333/hello', function(error, response, body) {
          body.should.eql("Hello World");
          done();
        });
      });

      it('prefers X-Api-Key over all other options', function(done) {
        request.get('http://invalid:@localhost:9333/hello?api_key=invalid', { headers: { 'X-Api-Key': this.apiKey } }, function(error, response, body) {
          body.should.eql("Hello World");
          done();
        });
      });

      it('prefers the GET param over basic auth username', function(done) {
        request.get('http://invalid:@localhost:9333/hello?api_key=' + this.apiKey, function(error, response, body) {
          body.should.eql("Hello World");
          done();
        });
      });
    });
  });
});
