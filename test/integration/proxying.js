'use strict';

require('../test_helper');

var async = require('async'),
    Curler = require('curler').Curler,
    Factory = require('factory-lady'),
    fs = require('fs'),
    http = require('http'),
    net = require('net'),
    randomstring = require('randomstring'),
    request = require('request'),
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
        response.statusCode.should.eql(200);
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

  // Ensure basic HTTP requests of all HTTP methods work with the entire stack
  // in place.
  //
  // This mainly stems from nodejs breaking OPTIONS requests without bodies
  // and Varnish really not liking it (this should be fixed in NodeJS v0.11):
  // https://github.com/joyent/node/pull/7725
  //
  // Also, this is a little tricky to test in node.js, since all OPTIONS
  // requests originating from node's http library currently add the chunked
  // headers (due to above issue). So we'll drop to a curl library to make
  // these test requests.
  describe('all http methods work', function() {
    describe('without request body', function() {
      ['GET', 'HEAD', 'DELETE', 'OPTIONS'].forEach(function(method) {
        it('successfully makes ' + method + ' requests', function(done) {
          var curl = new Curler();
          curl.request({
            method: method,
            url: 'http://localhost:9080/info/?api_key=' + this.apiKey,
          }, function(error, response) {
            response.statusCode.should.eql(200);
            done();
          });
        });
      });
    });

    describe('with request body', function() {
      ['POST', 'PUT', 'OPTIONS', 'PATCH'].forEach(function(method) {
        it('successfully makes ' + method + ' requests', function(done) {
          var curl = new Curler();
          curl.request({
            method: method,
            url: 'http://localhost:9080/info/?api_key=' + this.apiKey,
            headers: {
              'Transfer-Encoding': 'chunked',
              'Content-Length': '4',
            },
            data: 'test',
          }, function(error, response) {
            response.statusCode.should.eql(200);
            done();
          });
        });
      });
    });
  });

  describe('server-side keep alive', function() {
    it('keeps 10 idle keepalive connections opened to the backend', function(done) {
      // Open a bunch of concurrent connections first, and then inspect the
      // number of number of connections still active afterwards.
      var options = { agentOptions: { maxSockets: 150 } };
      async.times(50, function(index, callback) {
        request.get('http://localhost:9080/keepalive9445/connections?api_key=' + this.apiKey, options, function(error, response) {
          response.statusCode.should.eql(200);
          callback(error);
        });
      }.bind(this), function() {
        request.get('http://localhost:9080/keepalive9445/connections?api_key=' + this.apiKey, function(error, response, body) {
          response.statusCode.should.eql(200);

          var data = JSON.parse(body);
          data.start.connections.should.eql(10);
          data.start.requests.should.eql(1);
          data.end.connections.should.eql(10);
          data.end.requests.should.eql(1);

          done();
        });
      }.bind(this));
    });

    it('allows the number of idle backend keepalive connections to be configured', function(done) {
      // Open a bunch of concurrent connections first, and then inspect the
      // number of number of connections still active afterwards.
      var options = { agentOptions: { maxSockets: 150 } };
      async.times(50, function(index, callback) {
        request.get('http://localhost:9080/keepalive9446/connections?api_key=' + this.apiKey, options, function(error, response) {
          response.statusCode.should.eql(200);
          callback(error);
        });
      }.bind(this), function() {
        request.get('http://localhost:9080/keepalive9446/connections?api_key=' + this.apiKey, function(error, response, body) {
          response.statusCode.should.eql(200);

          var data = JSON.parse(body);
          data.start.connections.should.eql(6);
          data.start.requests.should.eql(1);
          data.end.connections.should.eql(6);
          data.end.requests.should.eql(1);

          done();
        });
      }.bind(this));
    });

    it('allows the number of concurrent connections to execeed the number of keepalive connections', function(done) {
      var maxConnections = 0;
      var maxRequests = 0;

      var options = { agentOptions: { maxSockets: 150 } };
      async.times(150, function(index, callback) {
        request.get('http://localhost:9080/keepalive9447/connections?api_key=' + this.apiKey, options, function(error, response, body) {
          response.statusCode.should.eql(200);

          var data = JSON.parse(body);

          if(data.start.connections > maxConnections) {
            maxConnections = data.start.connections;
          }

          if(data.start.requests > maxRequests) {
            maxRequests = data.start.requests;
          }

          callback(error);
        });
      }.bind(this), function() {
        // We sent 150 concurrent requests, but the number of concurrent
        // requests to the backend will likely be lower, since we're testing
        // the full stack, and the requests have to go through multiple layers
        // (the gatekeeper, caching, etc) which may lower absolute concurrency.
        // But all we're really trying to test here is that this does increase
        // above the 10 keepalived connections.
        maxRequests.should.be.greaterThan(25);
        maxConnections.should.be.greaterThan(25);

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
});
