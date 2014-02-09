'use strict';

require('../test_helper');

var async = require('async'),
    fs = require('fs'),
    http = require('http'),
    stk = require('stream-tk'),
    temp = require('temp');

temp.track();

describe('proxying', function() {
  beforeEach(function(done) {
    Factory.create('api_user', function(user) {
      this.apiKey = user.api_key;
      done();
    }.bind(this));
  });

  describe('streaming', function() {
    // TODO: nginx doesn't support chunked request streaming:
    // http://forum.nginx.org/read.php?2,243073,243074#msg-243074
    //
    // Revisit this under HAProxy 1.5
    xit('streams requests', function(done) {
      var req = http.request({
        host: 'localhost',
        port: 9080,
        //port: 9444,
        path: '/receive_chunks?api_key=' + this.apiKey,
        method: 'POST',
        headers: {
          'Transfer-Encoding': 'chunked',
        },
      }, function(response) {
        var body = '';
        response.on('data', function(chunk) {
          body += chunk.toString();
        });

        response.on('end', function() {
          var data = JSON.parse(body);
          data.chunks.should.eql([
            'hello',
            'greetings',
            'goodbye',
          ]);

          data.chunkTimeGaps.length.should.eql(2);
          data.chunkTimeGaps[0].should.be.greaterThan(400);
          data.chunkTimeGaps[1].should.be.greaterThan(400);

          data.request_encoding.should.eql('chunked');

          done();
        });
      });

      req.setNoDelay(true);

      req.write('hello');
      setTimeout(function() {
        req.write('greetings');
        setTimeout(function() {
          req.write('goodbye');
          req.end();
        }, 500);
      }, 500);
    });

    it('streams responses', function(done) {
      http.get('http://localhost:9080/chunked?api_key=' + this.apiKey, function(response) {
        var chunks = [];
        var chunkTimeGaps = [];
        var lastChunkTime;
        response.on('data', function(chunk) {
          chunks.push(chunk.toString());

          if(lastChunkTime) {
            var gap = Date.now() - lastChunkTime;
            chunkTimeGaps.push(gap);
          }

          lastChunkTime = Date.now();
        });

        response.on('end', function() {
          chunks.should.eql([
            'hello',
            'salutations',
            'goodbye',
          ]);

          chunkTimeGaps.length.should.eql(2);
          chunkTimeGaps[0].should.be.greaterThan(400);
          chunkTimeGaps[1].should.be.greaterThan(400);

          response.headers['transfer-encoding'].should.eql('chunked');

          done();
        });
      });
    });
  });

  it('accepts large uploads', function(done) {
    this.timeout(10000);

    var size = 20 * 1024 * 1024;
    var random = stk.createRandom('read', size);
    var stream = temp.createWriteStream();
    random.pipe(stream);
    stream.on('finish', function() {
      var req = request.post('http://localhost:9080/upload?api_key=' + this.apiKey, function(error, response, body) {
        var data = JSON.parse(body);
        data.upload_size.should.eql(size);
        done();
      });

      var form = req.form();
      form.append('upload', fs.createReadStream(stream.path));
    }.bind(this));
  });

  describe('timeouts', function() {
    it('times out quickly if a backend is down', function(done) {
      this.timeout(500);
      request.get('http://localhost:9080/down?api_key=' + this.apiKey, function(error, response) {
        response.statusCode.should.eql(502);
        done();
      });
    });

    it('behaves with 60-second connection timeouts', function(done) {
      this.timeout(75000);

      var apiKey = this.apiKey;

      // Parallelize all the 60-second timeout tests. Ideally these would be
      // represented as separate tests, but since mocha doesn't support
      // parallel tests, running these serially can quickly add up. So until
      // there's a better option, we'll run all these inside a single test in
      // parallel.
      async.parallel([
        // times out after 60 seconds if a backend is non-respnosive
        function(callback) {
          var startTime = Date.now();
          request.get('http://localhost:9080/delay/65000?api_key=' + apiKey, function(error, response) {
            response.statusCode.should.eql(504);

            var duration = Date.now() - startTime;
            duration.should.be.greaterThan(60000);
            duration.should.be.lessThan(65000);
            callback();
          });
        },

        // doesn't time out if a backend starts sending the request within 60
        // seconds
        function(callback) {
          request.get('http://localhost:9080/delays/57000/65000?api_key=' + apiKey, function(error, response, body) {
            response.statusCode.should.eql(200);
            body.should.eql('firstdone');
            callback();
          });
        },

        // doesn't time out if a backend sends chunks at least once every 60
        // seconds
        function(callback) {
          request.get('http://localhost:9080/delays/7000/65000?api_key=' + apiKey, function(error, response, body) {
            response.statusCode.should.eql(200);
            body.should.eql('firstdone');
            callback();
          });
        },

        // closes the response if the backend waits more than 60 seconds
        // between sending chunks
        function(callback) {
          request.get('http://localhost:9080/delays/3000/65000?api_key=' + apiKey, function(error, response, body) {
            response.statusCode.should.eql(200);
            body.should.eql('first');
            callback();
          });
        },
      ], done);
    });
  });

  describe('keep alive', function() {
  });
});
