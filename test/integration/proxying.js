'use strict';

require('../test_helper');

var async = require('async'),
    fs = require('fs'),
    http = require('http'),
    net = require('net'),
    randomstring = require('randomstring'),
    stk = require('stream-tk'),
    temp = require('temp');

temp.track();

describe('proxying', function() {
  beforeEach(function(done) {
    Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
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

  describe('header size', function() {
    function requestOfHeaderSize(options, callback) {
      var rawRequest = 'GET /info/ HTTP/1.1\r\n' +
        'X-Api-Key: ' + options.apiKey + '\r\n' +
        'Host: localhost:9080\r\n' +
        'Connection: close\r\n';

      var index = 5;
      while(rawRequest.length < options.size) {
        if(index > options.numHeaders) {
          break;
        }

        var headerName = 'X-Test' + index + ': ';
        rawRequest += headerName +
          randomstring.generate(options.lineLength - headerName.length - 2) +
          '\r\n';
        index++;
      }

      rawRequest = rawRequest.substring(0, options.size - 4) + '\r\n\r\n';

      if(options.numHeaders) {
        rawRequest.replace(/\s*$/, '').split('\r\n').length.should.eql(options.numHeaders);
      } else {
        rawRequest.length.should.eql(options.size);
      }

      var client = net.connect(9080, '127.0.0.1', function() {
        client.write(rawRequest);
      });

      var response = '';
      client.on('data', function(data) {
        response += data.toString();
      });

      client.on('end', function() {
        var parts = response.split('\r\n\r\n');
        callback(parts[0], parts[1]);
      });
    }

    it('allows a total header size of up to 32KB-ish', function(done) {
      requestOfHeaderSize({ size: 32000, lineLength: 4048, apiKey: this.apiKey }, function(headers, body) {
        headers.should.contain('200 OK');
        body.should.contain('"x-test5":');
        done();
      });
    });

    it('returns 400 bad request when the total header size exceeds 32KB-ish', function(done) {
      requestOfHeaderSize({ size: 34000, lineLength: 4048, apiKey: this.apiKey }, function(headers) {
        headers.should.contain('400 Bad Request');
        done();
      });
    });

    it('allows an individual header to be 8KB', function(done) {
      requestOfHeaderSize({ size: 12000, lineLength: 8192, apiKey: this.apiKey }, function(headers, body) {
        headers.should.contain('200 OK');

        var data = JSON.parse(body);
        var headerLength = data.headers['x-test5'].length;
        headerLength += 'x-test5: \r\n'.length;
        headerLength.should.eql(8192);

        done();
      });
    });

    it('returns 400 bad request when an individual header exceeds 8KB', function(done) {
      requestOfHeaderSize({ size: 12000, lineLength: 8193, apiKey: this.apiKey }, function(headers) {
        headers.should.contain('400 Bad Request');
        done();
      });
    });

    it('allows up to 53 header lines', function(done) {
      requestOfHeaderSize({ size: 12000, lineLength: 24, numHeaders: 53, apiKey: this.apiKey }, function(headers, body) {
        headers.should.contain('200 OK');
        body.should.contain('"x-test53":');
        body.should.not.contain('"x-test54":');
        done();
      });
    });

    it('returns 413 request entity too large when the number of header lines exceeds 53', function(done) {
      requestOfHeaderSize({ size: 12000, lineLength: 24, numHeaders: 54, apiKey: this.apiKey }, function(headers) {
        headers.should.contain('413 Request Entity Too Large');
        done();
      });
    });
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
