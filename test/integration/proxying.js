'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    config = require('../support/config'),
    Curler = require('curler').Curler,
    execFile = require('child_process').execFile,
    Factory = require('factory-lady'),
    fs = require('fs'),
    http = require('http'),
    randomstring = require('randomstring'),
    request = require('request'),
    stk = require('stream-tk'),
    temp = require('temp'),
    zlib = require('zlib');

temp.track();

describe('proxying', function() {
  shared.runServer({
    apis: [
      {
        _id: 'down',
        frontend_host: 'localhost',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9450,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/down',
            backend_prefix: '/down',
          },
        ],
      },
      {
        _id: 'keepalive9445',
        frontend_host: 'localhost',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9445,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/keepalive9445/',
            backend_prefix: '/keepalive9445/',
          },
        ],
      },
      {
        _id: 'keepalive9446',
        frontend_host: 'localhost',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9446,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/keepalive9446/',
            backend_prefix: '/keepalive9446/',
          },
        ],
        keepalive_connections: 2,
      },
      {
        _id: 'keepalive9447',
        frontend_host: 'localhost',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9447,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/keepalive9447/',
            backend_prefix: '/keepalive9447/',
          },
        ],
      },
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
            frontend_prefix: '/add-auth-header/',
            backend_prefix: '/',
          },
        ],
        settings: {
          http_basic_auth: 'somebody:secret',
        },
      },
      {
        frontend_host: 'abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij',
        backend_host: 'abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij',
        servers: [
          {
            host: '127.0.0.1',
            port: 9444,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/long-host-info/',
            backend_prefix: '/info/',
          },
        ],
      },
      {
        _id: 'circular-backend',
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
            frontend_prefix: '/circular-backend/',
            backend_prefix: '/info/circular-example/',
          },
        ],
        settings: {
          disable_api_key: true,
        },
      },
      {
        _id: 'circular-frontend',
        frontend_host: 'localhost',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9080,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/circular/',
            backend_prefix: '/circular-backend/',
          },
        ],
        settings: {
          disable_api_key: true,
        },
      },
      {
        _id: 'example',
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
            frontend_prefix: '/',
            backend_prefix: '/',
          },
        ],
      },
    ],
  });

  beforeEach(function createUser(done) {
    Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
      this.apiKey = user.api_key;
      this.options = {
        headers: {
          'X-Api-Key': this.apiKey,
        },
        agentOptions: {
          maxSockets: 500,
        },
      };

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
      var options = _.merge({}, this.options, {
        url: 'http://localhost:9080/chunked',
      });

      shared.chunkedRequestDetails(options, function(response, data) {
        data.stringChunks.should.eql([
          'hello',
          'salutations',
          'goodbye',
        ]);

        data.chunkTimeGaps.length.should.eql(2);
        data.chunkTimeGaps[0].should.be.greaterThan(400);
        data.chunkTimeGaps[1].should.be.greaterThan(400);

        response.headers['transfer-encoding'].should.eql('chunked');

        done();
      });
    });
  });

  it('accepts large uploads', function(done) {
    this.timeout(15000);

    var size = 20 * 1024 * 1024;
    var random = stk.createRandom('read', size);
    var stream = temp.createWriteStream();
    random.pipe(stream);
    stream.on('finish', function() {
      var req = request.post('http://localhost:9080/upload', this.options, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.upload_size.should.eql(size);
        done();
      });

      var form = req.form();
      form.append('upload', fs.createReadStream(stream.path));
    }.bind(this));
  });

  describe('url length', function() {
    it('allows a url length of 8KB', function(done) {
      var otherHeaderLineContent = 'GET  HTTP/1.1\r\n';
      var urlPath = '/info/?';
      urlPath += randomstring.generate(8192 - urlPath.length - otherHeaderLineContent.length);
      var url = 'http://localhost:9080' + urlPath;

      request.get(url, this.options, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.url.path.should.eql(urlPath);
        done();
      });
    });

    it('returns 414 request uri too large when  of 8KB', function(done) {
      var otherHeaderLineContent = 'GET  HTTP/1.1\r\n';
      var urlPath = '/info/?';
      urlPath += randomstring.generate(8193 - urlPath.length - otherHeaderLineContent.length);
      var url = 'http://localhost:9080' + urlPath;

      request.get(url, this.options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(414);
        done();
      });
    });
  });

  describe('header size', function() {
    function requestOfHeaderSize(options, callback) {
      var headers = {
        'X-Api-Key': options.apiKey,
        'Host': 'localhost:9080',
        'Connection': 'close',
      };

      var headerLineExtraLength = ': \r\n'.length;

      var rawRequestLength = 'GET /info/ HTTP/1.1\r\n'.length;
      for(var key in headers) {
        rawRequestLength += key.length;
        rawRequestLength += headers[key].length;
        rawRequestLength += headerLineExtraLength;
      }

      var index = 5;
      while(rawRequestLength < options.size) {
        if(index > options.numHeaders) {
          break;
        }

        var headerName = 'X-Test' + index;
        headers[headerName] = randomstring.generate(options.lineLength - headerName.length - headerLineExtraLength);

        rawRequestLength += headerName.length;
        rawRequestLength += headers[headerName].length;
        rawRequestLength += headerLineExtraLength;

        var overSizeLimitBy = rawRequestLength - options.size;
        if(overSizeLimitBy > 0) {
          headers[headerName] = headers[headerName].substring(0, headers[headerName].length - overSizeLimitBy);
        }

        index++;
      }

      request.get('http://localhost:9080/info/', { headers: headers }, function(error, response, body) {
        callback(response, body);
      });
    }

    it('allows a total header size of up to 32KB-ish', function(done) {
      requestOfHeaderSize({ size: 32000, lineLength: 4048, apiKey: this.apiKey }, function(response, body) {
        response.statusCode.should.eql(200);
        body.should.contain('"x-test5":');
        done();
      });
    });

    it('returns 400 bad request when the total header size exceeds 32KB-ish', function(done) {
      requestOfHeaderSize({ size: 34000, lineLength: 4048, apiKey: this.apiKey }, function(response) {
        response.statusCode.should.eql(400);
        done();
      });
    });

    it('allows an individual header to be 8KB', function(done) {
      requestOfHeaderSize({ size: 12000, lineLength: 8192, apiKey: this.apiKey }, function(response, body) {
        response.statusCode.should.eql(200);

        var data = JSON.parse(body);
        var headerLength = data.headers['x-test5'].length;
        headerLength += 'x-test5: \r\n'.length;
        headerLength.should.eql(8192);

        done();
      });
    });

    it('returns 400 bad request when an individual header exceeds 8KB', function(done) {
      requestOfHeaderSize({ size: 12000, lineLength: 8193, apiKey: this.apiKey }, function(response) {
        response.statusCode.should.eql(400);
        done();
      });
    });

    if(global.CACHING_SERVER === 'varnish') {
      // Varnish has a limit on the number of HTTP header lines. This is 64 lines
      // by default. But because our stack adds a variety of extra headers (eg,
      // x-forwarded-for, x-api-umbrella-key, etc), by the time the request gets
      // to Varnish, it means we can really only pass 54 lines in as the original
      // request.
      it('allows up to 54 header lines (really 64 lines at the Varnish layer)', function(done) {
        requestOfHeaderSize({ size: 12000, lineLength: 24, numHeaders: 54, apiKey: this.apiKey }, function(response, body) {
          response.statusCode.should.eql(200);
          body.should.contain('"x-test54":');
          body.should.not.contain('"x-test55":');
          done();
        });
      });

      it('returns 400 request entity too large when the number of header lines exceeds 54 (really 64 lines at the Varnish layer)', function(done) {
        requestOfHeaderSize({ size: 12000, lineLength: 24, numHeaders: 55, apiKey: this.apiKey }, function(response) {
          response.statusCode.should.eql(400);
          done();
        });
      });
    } else {
      it('places no distinct limit on the number of individual lines in the header', function(done) {
        requestOfHeaderSize({ size: 12000, lineLength: 24, numHeaders: 150, apiKey: this.apiKey }, function(response, body) {
          response.statusCode.should.eql(200);
          body.should.contain('"x-test150":');
          body.should.not.contain('"x-test151":');
          done();
        });
      });
    }

    it('supports long hostnames without additional config when part of api backend hosts', function(done) {
      var options = _.merge({}, this.options, {
        headers: {
          'Host': 'abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij',
        },
      });

      request.get('http://localhost:9080/long-host-info/', options, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.headers.host.length.should.eql(200);
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
            response.headers['x-received-method'].should.eql(method);
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
            response.headers['x-received-method'].should.eql(method);
            done();
          });
        });
      });
    });

    describe('disallowed', function() {
      it('returns 405 not allowed error for TRACE requests', function(done) {
        var curl = new Curler();
        curl.request({
          method: 'TRACE',
          url: 'http://localhost:9080/info/?api_key=' + this.apiKey,
        }, function(error, response) {
          response.statusCode.should.eql(405);
          done();
        });
      });
    });
  });

  describe('client-side keep alive', function() {
    it('reuses connections', function(done) {
      var url = 'http://localhost:9080/hello/?api_key=' + this.apiKey;
      execFile('curl', ['-v', url, url], function(error, stdout, stderr) {
        stdout.should.eql('Hello WorldHello World');
        stderr.should.match(/200 OK[\s\S]+Re-using existing connection[\s\S]+200 OK/);
        done();
      });
    });
  });

  describe('server-side keep alive', function() {
    it('keeps 10 idle keepalive connections (per nginx worker) opened to the backend', function(done) {
      this.timeout(30000);

      var options = _.merge({}, this.options, {
        headers: {
          'Connection': 'close',
        },
      });

      // Open a bunch of concurrent connections first, and then inspect the
      // number of number of connections still active afterwards.
      async.times(400, function(index, callback) {
        request.get('http://localhost:9080/keepalive9445/connections?index=' + index, options, function(error, response) {
          callback(error, response.statusCode);
        });
      }.bind(this), function(error, responseCodes) {
        should.not.exist(error);
        responseCodes.length.should.eql(400);
        _.uniq(responseCodes).should.eql([200]);

        setTimeout(function() {
          request.get('http://localhost:9080/keepalive9445/connections', options, function(error, response, body) {
            response.statusCode.should.eql(200);

            var data = JSON.parse(body);
            data.requests.should.eql(1);

            // The number of active connections afterwards should be between 10
            // and 40 (10 * number of nginx worker processes). This ambiguity
            // is because we may not have exercised all the individual nginx
            // workers. Since we're mainly interested in ensuring some unused
            // connections are being kept open, we'll loosen our count checks.
            data.connections.should.be.gte(10);
            data.connections.should.be.lte(10 * 4);

            done();
          });
        }.bind(this), 50);
      }.bind(this));
    });

    it('allows the number of idle backend keepalive connections (per nginx worker) to be configured', function(done) {
      this.timeout(30000);

      var options = _.merge({}, this.options, {
        headers: {
          'Connection': 'close',
        },
      });

      // Open a bunch of concurrent connections first, and then inspect the
      // number of number of connections still active afterwards.
      async.times(400, function(index, callback) {
        request.get('http://localhost:9080/keepalive9446/connections?index=' + index, options, function(error, response) {
          callback(error, response.statusCode);
        });
      }.bind(this), function(error, responseCodes) {
        should.not.exist(error);
        responseCodes.length.should.eql(400);
        _.uniq(responseCodes).should.eql([200]);

        setTimeout(function() {
          request.get('http://localhost:9080/keepalive9446/connections', options, function(error, response, body) {
            response.statusCode.should.eql(200);

            var data = JSON.parse(body);
            data.requests.should.eql(1);

            // The number of active connections afterwards for this specific
            // API should be between 2 and 8 (2 * number of nginx worker
            // processes).
            data.connections.should.be.gte(2);
            data.connections.should.be.lte(2 * 4);

            // Given the ambiguity of the connection ranges, make an explicit
            // check to ensure this test remains below the default 10 keepalive
            // connections.
            data.connections.should.be.lt(10);

            done();
          });
        }.bind(this), 50);
      }.bind(this));
    });

    it('allows the number of concurrent connections to execeed the number of keepalive connections', function(done) {
      this.timeout(30000);

      var options = _.merge({}, this.options, {
        headers: {
          'Connection': 'close',
        },
      });

      var maxConnections = 0;
      var maxRequests = 0;
      async.times(400, function(index, callback) {
        request.get('http://localhost:9080/keepalive9447/connections?index=' + index, options, function(error, response, body) {
          var data = JSON.parse(body);

          if(data.connections > maxConnections) {
            maxConnections = data.connections;
          }

          if(data.requests > maxRequests) {
            maxRequests = data.requests;
          }

          callback(error, response.statusCode);
        });
      }.bind(this), function(error, responseCodes) {
        should.not.exist(error);
        responseCodes.length.should.eql(400);
        _.uniq(responseCodes).should.eql([200]);

        // We sent 400 concurrent requests, but the number of concurrent
        // requests to the backend will likely be lower, since we're testing
        // the full stack, and the requests have to go through multiple layers
        // (the gatekeeper, caching, etc) which may lower absolute concurrency.
        // But all we're really trying to test here is that this does increase
        // above the default of 40 keepalive connections per backend.
        maxRequests.should.be.greaterThan(40);
        maxConnections.should.be.greaterThan(40);

        done();
      });
    });
  });

  describe('gzip', function() {
    describe('backend returning non-gzipped content', function() {
      it('gzips the response when the content length is greather than or equal to 1000', function(done) {
        var options = _.merge({}, this.options, { gzip: true });
        request.get('http://localhost:9080/compressible/1000', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          response.headers['content-encoding'].should.eql('gzip');
          body.toString().length.should.eql(1000);
          done();
        });
      });

      it('does not gzip the response when the content length is less than 1000', function(done) {
        var options = _.merge({}, this.options, { gzip: true });
        request.get('http://localhost:9080/compressible/999', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          should.not.exist(response.headers['content-encoding']);
          body.toString().length.should.eql(999);
          done();
        });
      });

      it('gzips chunked responses of any size', function(done) {
        var options = _.merge({}, this.options, { gzip: true });
        request.get('http://localhost:9080/compressible-delayed-chunked/5', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          response.headers['content-encoding'].should.eql('gzip');
          body.toString().length.should.eql(15);
          done();
        });
      });

      it('returns unzipped response when unsupported', function(done) {
        var options = _.merge({}, this.options, { gzip: false });
        request.get('http://localhost:9080/compressible/1000', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          should.not.exist(response.headers['content-encoding']);
          body.toString().length.should.eql(1000);
          done();
        });
      });
    });

    describe('backend returning pre-gzipped content', function() {
      it('returns gzipped response when supported', function(done) {
        var options = _.merge({}, this.options, { gzip: true });
        request.get('http://localhost:9080/compressible-pre-gzip', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          response.headers['content-encoding'].should.eql('gzip');
          body.toString().should.eql('Hello Small World');
          done();
        });
      });

      it('returns unzipped response when unsupported', function(done) {
        var options = _.merge({}, this.options, { gzip: false });
        request.get('http://localhost:9080/compressible-pre-gzip', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          should.not.exist(response.headers['content-encoding']);
          body.toString().should.eql('Hello Small World');
          done();
        });
      });
    });

    describe('compressible response types', function() {
      [
        '', // Gets turned into text/plain
        'application/atom+xml',
        'application/javascript',
        'application/json',
        'application/rss+xml',
        'application/x-javascript',
        'application/xml',
        'text/css',
        'text/csv',
        'text/html',
        'text/javascript',
        'text/plain',
        'text/xml',
      ].forEach(function(mime) {
        it('returns gzip response for "' + mime + '" content type', function(done) {
          var options = _.merge({}, this.options, {
            url: 'http://localhost:9080/compressible/1000',
            qs: {
              content_type: mime,
            },
            gzip: true,
          });

          request(options, function(error, response, body) {
            response.statusCode.should.eql(200);
            response.headers['content-encoding'].should.eql('gzip');
            body.toString().length.should.eql(1000);
            done();
          });
        });
      });
    });

    describe('non-compressible response types', function() {
      [
        'image/png',
        'application/octet-stream',
        'application/x-perl',
        'application/x-whatever-unknown',
      ].forEach(function(mime) {
        it('returns non-gzip response for "' + mime + '" content type', function(done) {
          var options = _.merge({}, this.options, {
            url: 'http://localhost:9080/compressible/1000',
            qs: {
              content_type: mime,
            },
            gzip: true,
          });

          request(options, function(error, response, body) {
            response.statusCode.should.eql(200);
            should.not.exist(response.headers['content-encoding']);
            body.toString().length.should.eql(1000);
            done();
          });
        });
      });
    });

    describe('response streaming', function() {
      it('streams back small chunks directly as gzipped chunks', function(done) {
        var options = _.merge({}, this.options, {
          url: 'http://localhost:9080/compressible-delayed-chunked/5',
          gzip: true,
        });

        shared.chunkedRequestDetails(options, function(response, data) {
          var buffer = Buffer.concat(data.chunks);
          zlib.gunzip(buffer, function(error, decodedBody) {
            should.not.exist(error);

            response.headers['content-encoding'].should.eql('gzip');
            response.headers['transfer-encoding'].should.eql('chunked');
            decodedBody.toString().length.should.eql(15);

            // Ensure we have at least 3 chunks (it may be 4, due to gzipping
            // messing with things).
            data.chunks.length.should.be.gte(3);

            // Make sure that there were 2 primary gaps between chunks from the
            // server (again, gzipping may introduce other chunks, but we're just
            // interested in ensuring the chunks sent back from the server are
            // present).
            var longTimeGaps = _.filter(data.chunkTimeGaps, function(gap) {
              return gap >= 400;
            });
            longTimeGaps.length.should.eql(2);

            done();
          });
        });
      });

      describe('when the underlying server supports gzip but the client does not', function() {
        it('streams back small uncompressed chunks', function(done) {
          var options = _.merge({}, this.options, {
            url: 'http://localhost:9080/compressible-delayed-chunked/10',
            gzip: false,
          });

          shared.chunkedRequestDetails(options, function(response, data) {
            should.not.exist(response.headers['content-encoding']);
            response.headers['transfer-encoding'].should.eql('chunked');
            data.bodyString.length.should.eql(30);

            data.chunks.length.should.eql(3);

            done();
          });
        });

        it('streams back large uncompressed chunks', function(done) {
          var options = _.merge({}, this.options, {
            url: 'http://localhost:9080/compressible-delayed-chunked/50000',
            gzip: false,
          });

          shared.chunkedRequestDetails(options, function(response, data) {
            should.not.exist(response.headers['content-encoding']);
            response.headers['transfer-encoding'].should.eql('chunked');
            data.bodyString.length.should.eql(150000);

            var longTimeGaps = _.filter(data.chunkTimeGaps, function(gap) {
              return gap >= 400;
            });

            var shortTimeGaps = _.filter(data.chunkTimeGaps, function(gap) {
              return gap < 400;
            });

            // With response sizes this big, we'll have a lot of response
            // chunks, but what we mainly want to test is that there are
            // distinct gaps in the chunks corresponding to how the backend
            // streams stuff back.
            longTimeGaps.length.should.eql(2);
            shortTimeGaps.length.should.be.greaterThan(10);

            done();
          });
        });
      });
    });

    // Varnish 3 exhibited invalid responses when streaming was enabled and
    // dealing with gzipped, chunked responses:
    // https://www.varnish-cache.org/trac/ticket/1220
    //
    // This was fixed in Varnish 4, but test to try and ensure our stack
    // remains compatible with this scenario of streaming gzipped, chunked
    // responses.
    it('successfully responds when dealing with large-ish, gzipped, chunked responses', function(done) {
      this.timeout(20000);

      var options = _.merge({}, this.options, {
        gzip: true,
      });

      // Varnish 3 broken behavior only cropped up sporadically, but larger
      // responses seem to have triggered the behavior more frequently.
      // Responses somewhere in the neighborhood of 252850 bytes seemed to make
      // this problem reproducible. So test everything from 252850 - 253850
      // bytes.
      var sizes = _.times(1000, function(index) { return index + 252850; });
      var results = [];
      async.eachLimit(sizes, 100, function(size, callback) {
        request.get('http://localhost:9080/compressible-chunked/1/' + size, options, function(error, response, body) {
          results.push({ size: size, body: body, headers: response.headers, responseCode: response.statusCode });
          callback(error);
        });
      }.bind(this), function(error) {
        should.not.exist(error);
        results.forEach(function(result) {
          result.responseCode.should.eql(200);
          result.headers['content-encoding'].should.eql('gzip');
          result.body.toString().length.should.eql(result.size);
        });

        done();
      });
    });

    // Normalize the Accept-Encoding header to maximize caching:
    // https://docs.trafficserver.apache.org/en/latest/reference/configuration/records.config.en.html?highlight=gzip#proxy-config-http-normalize-ae-gzip
    describe('accept-encoding normalization', function() {
      it('leaves accept-encoding equalling "gzip"', function(done) {
        var options = _.merge({}, this.options, {
          gzip: true,
          headers: {
            'Accept-Encoding': 'gzip',
          },
        });

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.headers['accept-encoding'].should.eql('gzip');
          done();
        });
      });

      it('changes accept-encoding containing "gzip" to just "gzip"', function(done) {
        var options = _.merge({}, this.options, {
          gzip: true,
          headers: {
            'Accept-Encoding': 'gzip, deflate, compress',
          },
        });

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.headers['accept-encoding'].should.eql('gzip');
          done();
        });
      });

      it('removes accept-encoding not containing "gzip"', function(done) {
        var options = _.merge({}, this.options, {
          gzip: true,
          headers: {
            'Accept-Encoding': 'deflate, compress',
          },
        });

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          should.not.exist(data.headers['accept-encoding']);
          done();
        });
      });

      it('removes accept-encoding containing "gzip", but not as a standalone entry ("gzipp")', function(done) {
        var options = _.merge({}, this.options, {
          gzip: true,
          headers: {
            'Accept-Encoding': 'gzipp',
          },
        });

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          should.not.exist(data.headers['accept-encoding']);
          done();
        });
      });

      it('removes accept-encoding if gzip is q=0', function(done) {
        var options = _.merge({}, this.options, {
          gzip: true,
          headers: {
            'Accept-Encoding': 'gzip;q=0',
          },
        });

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          should.not.exist(data.headers['accept-encoding']);
          done();
        });
      });

      it('removes accept-encoding if gzip is q=0.00', function(done) {
        var options = _.merge({}, this.options, {
          gzip: true,
          headers: {
            'Accept-Encoding': 'gzip;q=0.00',
          },
        });

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          should.not.exist(data.headers['accept-encoding']);
          done();
        });
      });

      it('keeps accept-encoding if gzip is q=0.01', function(done) {
        var options = _.merge({}, this.options, {
          gzip: true,
          headers: {
            'Accept-Encoding': 'gzip;q=0.01',
          },
        });

        request.get('http://localhost:9080/info/', options, function(error, response, body) {
          response.statusCode.should.eql(200);
          var data = JSON.parse(body);
          data.headers['accept-encoding'].should.eql('gzip');
          done();
        });
      });
    });

    describe('gzip recieved by backend', function() {
      it('recieves a gzip accept-encoding header when the client supports gzip', function(done) {
        var url = 'http://localhost:9080/info/?accept_encoding_randomize=' + _.uniqueId();
        var options = _.merge({}, this.options, {
          gzip: true,
        });

        async.timesSeries(3, function(index, callback) {
          request.get(url, options, function(error, response, body) {
            response.statusCode.should.eql(200);
            var data = JSON.parse(body);
            data.headers['accept-encoding'].should.eql('gzip');
            callback();
          });
        }, done);
      });

      it('recieves no accept-encoding header when the client does not support gzip', function(done) {
        var url = 'http://localhost:9080/info/?accept_encoding_randomize=' + _.uniqueId();
        var options = _.merge({}, this.options, {
          headers: {
            'Accept-Encoding': '',
          },
        });

        async.timesSeries(3, function(index, callback) {
          request.get(url, options, function(error, response, body) {
            response.statusCode.should.eql(200);
            var data = JSON.parse(body);
            should.not.exist(data.headers['accept-encoding']);
            callback();
          });
        }, done);
      });
    });
  });

  describe('content type', function() {
    // This is a side-effect of setting the X-Cache header in OpenResty. It
    // appears like OpenResty forces a default text/plain content-type when it
    // changes any other header if the content-type isn't already set. If this
    // changes in the future to retaining no header, that should be fine, just
    // testing current behavior.
    it('turns an empty content-type response header into text/plain', function(done) {
      var options = _.merge({}, this.options, {
        url: 'http://localhost:9080/compressible/1000',
        qs: {
          content_type: '',
        },
        gzip: true,
      });

      request(options, function(error, response) {
        response.statusCode.should.eql(200);
        response.headers['content-type'].should.eql('text/plain');
        done();
      });
    });

    it('keeps any existing contet-type as is', function(done) {
      var options = _.merge({}, this.options, {
        url: 'http://localhost:9080/compressible/1000',
        qs: {
          content_type: 'Qwerty',
        },
        gzip: true,
      });

      request(options, function(error, response) {
        response.statusCode.should.eql(200);
        response.headers['content-type'].should.eql('Qwerty');
        done();
      });
    });
  });

  describe('chunked response behavior', function() {
    // TODO: Ideally when a backend returns a non-chunked response it would be
    // returned to the client as non-chunked, but Varnish appears to sometimes
    // randomly change non-chunked responses into chunked responses.
    // Update if Varnish's behavior changes:
    // https://www.varnish-cache.org/trac/ticket/1506
    //
    // So for now, we're simply testing to ensure that a portion of
    // chunked/non-chunked responses get returned as expected. So these test
    // aren't exactly precise, but ensure we're testing the basic chunking
    // behavior.
    //
    // Note, Varnish seems to vary more in whether it decides to chunk or not
    // chunk responses based on available system memory and resources (I've
    // noticed when lower on memory, it consistently decides to turn chunked
    // responses into non-chunked responses). So if these tests fail, consider
    // system resources, or we might end up disabling these altogether.
    function countChunkedResponses(options, count, size, done) {
      var chunkedCount = 0;
      var nonChunkedCount = 0;

      var requests = _.times(count, function(index) { return index; });
      var results = [];
      async.eachLimit(requests, 10, function(index, callback) {
        request(options, function(error, response, body) {
          results.push({ body: body, headers: response.headers, responseCode: response.statusCode });
          callback(error);
        });
      }, function(error) {
        should.not.exist(error);
        results.forEach(function(result) {
          result.responseCode.should.eql(200);

          if(result.headers['transfer-encoding']) {
            result.headers['transfer-encoding'].should.eql('chunked');
            should.not.exist(result.headers['content-length']);
            chunkedCount++;
          } else {
            should.not.exist(result.headers['transfer-encoding']);
            should.exist(result.headers['content-length']);
            nonChunkedCount++;
          }

          result.body.toString().length.should.eql(size);
        });

        done({
          chunked: chunkedCount,
          nonChunked: nonChunkedCount,
          total: chunkedCount + nonChunkedCount,
        });
      });
    }

    [true, false].forEach(function(gzipEnabled) {
      describe('gzip enabled: ' + gzipEnabled, function() {
        beforeEach(function() {
          _.merge(this.options, { gzip: gzipEnabled });
        });

        it('returns small non-chunked responses', function(done) {
          this.timeout(10000);
          _.merge(this.options, { url: 'http://localhost:9080/compressible/10' });
          countChunkedResponses(this.options, 50, 10, function(counts) {
            counts.total.should.eql(50);
            counts.nonChunked.should.be.greaterThan(15);
            done();
          });
        });

        // nginx's gzipping chunks responses, even if they weren't before.
        if(gzipEnabled) {
          it('returns larger non-chunked responses as chunked when gzip is enabled', function(done) {
            this.timeout(10000);
            _.merge(this.options, { url: 'http://localhost:9080/compressible/100000' });
            countChunkedResponses(this.options, 50, 100000, function(counts) {
              counts.total.should.eql(50);
              counts.chunked.should.be.greaterThan(15);
              done();
            });
          });
        } else {
          it('returns larger non-chunked responses as non-chunked when gzip is disabled', function(done) {
            this.timeout(10000);
            _.merge(this.options, { url: 'http://localhost:9080/compressible/10000' });
            countChunkedResponses(this.options, 50, 10000, function(counts) {
              counts.total.should.eql(50);
              // The number of non-chunked responses we see is sporadically
              // quite low. I think this might be due to how Varnish buffers
              // things. We can revisit this, but this chunked vs non-chunked
              // behavior probably isn't a huge deal.
              counts.nonChunked.should.be.greaterThan(1);
              done();
            });
          });
        }

        it('returns small chunked responses', function(done) {
          this.timeout(10000);
          _.merge(this.options, { url: 'http://localhost:9080/compressible-chunked/1/500' });
          countChunkedResponses(this.options, 50, 500, function(counts) {
            counts.total.should.eql(50);
            counts.chunked.should.be.greaterThan(15);
            done();
          });
        });

        it('returns larger chunked responses', function(done) {
          this.timeout(10000);
          _.merge(this.options, { url: 'http://localhost:9080/compressible-chunked/50/2000' });
          countChunkedResponses(this.options, 50, 100000, function(counts) {
            counts.total.should.eql(50);
            counts.chunked.should.be.greaterThan(15);
            done();
          });
        });
      });
    });
  });

  describe('cookies', function() {
    it('strips analytics cookies', function(done) {
      var options = _.merge({}, this.options, {
        headers: {
          'Cookie': '__utma=foo; foo=bar; _ga=test; moo=boo',
        },
      });

      request.get('http://localhost:9080/info/', options, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.headers['cookie'].should.eql('foo=bar; moo=boo');
        done();
      });
    });
  });

  describe('url encoding', function() {
    it('passes utf8 characters in the URL', function(done) {
      // Use curl and not request for these tests, since the request library
      // calls url.parse which has a bug that causes backslashes to become
      // forward slashes https://github.com/joyent/node/pull/8459
      var curl = new Curler();
      curl.request({
        method: 'GET',
        url: 'http://localhost:9080/info/utf8/✓/encoded_utf8/%E2%9C%93/?api_key=' + this.apiKey + '&unique_query_id=' + this.uniqueQueryId + '&utf8=✓&utf8_url_encoded=%E2%9C%93&more_utf8=¬¶ªþ¤l&more_utf8_hex=\xAC\xB6\xAA\xFE\xA4l&more_utf8_hex_lowercase=\xac\xb6\xaa\xfe\xa4l&actual_backslash_x=\\xAC\\xB6\\xAA\\xFE\\xA4l',
      }, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.url.query.utf8.should.eql('✓');
        data.url.query.utf8_url_encoded.should.eql('✓');
        data.url.query.more_utf8.should.eql('¬¶ªþ¤l');
        data.url.query.more_utf8_hex.should.eql('¬¶ªþ¤l');
        data.url.query.more_utf8_hex_lowercase.should.eql('¬¶ªþ¤l');
        data.raw_url.should.endWith('/info/utf8/%E2%9C%93/encoded_utf8/%E2%9C%93/?unique_query_id=' + this.uniqueQueryId + '&utf8=✓&utf8_url_encoded=%E2%9C%93&more_utf8=¬¶ªþ¤l&more_utf8_hex=\xAC\xB6\xAA\xFE\xA4l&more_utf8_hex_lowercase=\xac\xb6\xaa\xfe\xa4l&actual_backslash_x=\\xAC\\xB6\\xAA\\xFE\\xA4l');
        done();
      });
    });

    it('passes backslashes and slashes in the URL', function(done) {
      // Use curl and not request for these tests, since the request library
      // calls url.parse which has a bug that causes backslashes to become
      // forward slashes https://github.com/joyent/node/pull/8459
      var curl = new Curler();
      curl.request({
        method: 'GET',
        url: 'http://localhost:9080/info/extra//slash/some\\backslash/encoded%5Cbackslash/encoded%2Fslash/?api_key=' + this.apiKey + '&unique_query_id=' + this.uniqueQueryId + '&forward_slash=/slash&encoded_forward_slash=%2F&back_slash=\\&encoded_back_slash=%5C',
      }, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.url.query.forward_slash.should.eql('/slash');
        data.url.query.encoded_forward_slash.should.eql('/');
        data.url.query.encoded_back_slash.should.eql('\\');
        data.raw_url.should.endWith('/info/extra/slash/some\\backslash/encoded\\backslash/encoded/slash/?unique_query_id=' + this.uniqueQueryId + '&forward_slash=/slash&encoded_forward_slash=%2F&back_slash=\\&encoded_back_slash=%5C');
        done();
      });
    });
  });

  describe('timeouts', function() {
    it('times out quickly if a backend is down', function(done) {
      this.timeout(500);
      request.get('http://localhost:9080/down', this.options, function(error, response) {
        response.statusCode.should.eql(502);
        done();
      });
    });

    it('behaves with configurable connection timeouts', function(done) {
      this.timeout(40000);

      var options = this.options;

      // Parallelize all the timeout tests. Ideally these would be
      // represented as separate tests, but since mocha doesn't support
      // parallel tests, running these serially can quickly add up. So until
      // there's a better option, we'll run all these inside a single test in
      // parallel.
      async.parallel([
        // times out after 10 seconds if a backend is non-responsive for GET
        // requests
        function(callback) {
          var startTime = Date.now();
          request.get('http://localhost:9080/delay/' + (config.get('nginx.proxy_connect_timeout') * 1000 + 5000), options, function(error, response) {
            response.statusCode.should.eql(504);

            var duration = Date.now() - startTime;
            duration.should.be.greaterThan(config.get('nginx.proxy_connect_timeout') * 1000);
            duration.should.be.lessThan(config.get('nginx.proxy_connect_timeout') * 1000 + 5000);
            callback();
          });
        },

        // times out after 10 seconds if a backend is non-responsive for
        // non-GET requests
        function(callback) {
          var startTime = Date.now();
          request.post('http://localhost:9080/delay/' + (config.get('nginx.proxy_connect_timeout') * 1000 + 5000), options, function(error, response) {
            response.statusCode.should.eql(504);

            var duration = Date.now() - startTime;
            duration.should.be.greaterThan(config.get('nginx.proxy_connect_timeout') * 1000);
            duration.should.be.lessThan(config.get('nginx.proxy_connect_timeout') * 1000 + 5000);
            callback();
          });
        },

        // doesn't time out if a backend starts sending the request within 10
        // seconds
        function(callback) {
          request.get('http://localhost:9080/delays/' + (config.get('nginx.proxy_read_timeout') * 1000 - 2000) + '/' + (config.get('nginx.proxy_connect_timeout') * 1000 + 5000), options, function(error, response, body) {
            response.statusCode.should.eql(200);
            body.should.eql('firstdone');
            callback();
          });
        },

        // doesn't time out if a backend sends chunks at least once every 10
        // seconds
        function(callback) {
          request.get('http://localhost:9080/delays/' + (config.get('nginx.proxy_read_timeout') * 1000 - 8000) + '/' + (config.get('nginx.proxy_read_timeout') * 1000), options, function(error, response, body) {
            response.statusCode.should.eql(200);
            body.should.eql('firstdone');
            callback();
          });
        },

        // closes the response if the backend waits more than 10 seconds
        // between sending chunks
        function(callback) {
          request.get('http://localhost:9080/delays/' + (config.get('nginx.proxy_read_timeout') * 1000 - 8000) + '/' + (config.get('nginx.proxy_read_timeout') * 1000 + 4000), options, function(error, response, body) {
            response.statusCode.should.eql(200);
            body.should.eql('first');
            callback();
          });
        },

        // allows concurrent requests to the same endpoint via different HTTP
        // methods.
        //
        // This is mainly done to ensure that any connection collapsing the
        // cache is doing, doesn't improperly hold up non-cacheable requests
        // waiting on a potentially cacheable request.
        function(callback) {
          var start = new Date();
          async.parallel([
            function(request_callback) {
              request.get('http://localhost:9080/delay/5000', options, function(error, response) {
                response.statusCode.should.eql(200);
                request_callback();
              });
            },
            function(request_callback) {
              setTimeout(function() {
                request.post('http://localhost:9080/delay/5000', options, function(error, response) {
                  response.statusCode.should.eql(200);
                  request_callback();
                });
              }, 1000);
            },
          ], function() {
            var end = new Date();
            var duration = end - start;
            duration.should.be.greaterThan(5000);
            duration.should.be.lessThan(9000);
            callback();
          });
        },

        // only sends 1 request to the backend on timeouts for GET requests
        //
        // This is to ensure that no proxy in front of the backend makes
        // multiple retry attempts when a request times out (since we don't
        // want to duplicate requests if a backend is already struggling).
        function(callback) {
          async.series([
            function(next) {
              request.get('http://127.0.0.1:9442/backend_call_count?id=get-timeout', function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.eql(200);
                body.should.eql('0');
                next();
              });
            },
            function(next) {
              request.get('http://localhost:9080/timeout', options, function(error, response) {
                response.statusCode.should.eql(504);
                next();
              });
            },
            function(next) {
              request.get('http://127.0.0.1:9442/backend_call_count?id=get-timeout', function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.eql(200);

                // Ensure that the backend has only been called once.
                body.should.eql('1');

                // Wait 5 seconds for any possible retry attempts that might be
                // pending, and then ensure the backend has still only been called
                // once.
                setTimeout(next, 5000);
              });
            },
            function(next) {
              request.get('http://127.0.0.1:9442/backend_call_count?id=get-timeout', function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.eql(200);
                body.should.eql('1');
                next();
              });
            },
          ], callback);
        },

        // only sends 1 request to the backend on timeouts for POST requests
        //
        // Same test as above, but ensure non-GET requests are behaving the
        // same (no retry allowed). This is probably even more important for
        // non-GET requests since duplicating POST requests could be harmful
        // (multiple creates, updates, etc).
        function(callback) {
          async.series([
            function(next) {
              request.get('http://127.0.0.1:9442/backend_call_count?id=post-timeout', function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.eql(200);
                body.should.eql('0');
                next();
              });
            },
            function(next) {
              request.post('http://localhost:9080/timeout', options, function(error, response) {
                response.statusCode.should.eql(504);
                next();
              });
            },
            function(next) {
              request.get('http://127.0.0.1:9442/backend_call_count?id=post-timeout', function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.eql(200);

                // Ensure that the backend has only been called once.
                body.should.eql('1');

                // Wait 5 seconds for any possible retry attempts that might be
                // pending, and then ensure the backend has still only been called
                // once.
                setTimeout(next, 5000);
              });
            },
            function(next) {
              request.get('http://127.0.0.1:9442/backend_call_count?id=post-timeout', function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.eql(200);
                body.should.eql('1');
                next();
              });
            },
          ], callback);
        },

        // only sends 1 request to the backend on timeouts that fall between
        // the varnish and nginx timeout
        //
        // Since we have to workaround Varnish's double request issue by
        // setting it's timeout longer than nginx's, just ensure everything
        // still works when something times according to nginx's timeout, but
        // not varnish's longer timeout.
        function(callback) {
          async.series([
            function(next) {
              request.get('http://127.0.0.1:9442/backend_call_count?id=post-between-varnish-timeout', function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.eql(200);
                body.should.eql('0');
                next();
              });
            },
            function(next) {
              request.get('http://localhost:9080/between-varnish-timeout', options, function(error, response) {
                response.statusCode.should.eql(504);
                next();
              });
            },
            function(next) {
              request.get('http://127.0.0.1:9442/backend_call_count?id=post-between-varnish-timeout', function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.eql(200);

                // Ensure that the backend has only been called once.
                body.should.eql('1');

                // Wait 5 seconds for any possible retry attempts that might be
                // pending, and then ensure the backend has still only been called
                // once.
                setTimeout(next, 5000);

              });
            },
            function(next) {
              request.get('http://127.0.0.1:9442/backend_call_count?id=post-between-varnish-timeout', function(error, response, body) {
                should.not.exist(error);
                response.statusCode.should.eql(200);
                body.should.eql('1');
                next();
              });
            },
          ], callback);
        },

        // doesn't consider the gatekeeper backends down after a bunch of
        // timeouts are encountered.
        //
        // This is to check the behavior of nginx's max_fails=0 in our
        // gatekeeper backend setup, to ensure a bunch of backend timeouts
        // don't accidentally remove all the gatekeepers from load balancing
        // rotation.
        function(callback) {
          async.times(50, function(index, timesCallback) {
            request.post('http://localhost:9080/delay/' + (config.get('nginx.proxy_connect_timeout') * 1000 + 5000), options, timesCallback);
          }, function() {
            async.times(50, function(index, timesCallback) {
              request.get('http://localhost:9080/info/', options, function(error, response) {
                timesCallback(error, response.statusCode);
              });
            }.bind(this), function(error, responseCodes) {
              should.not.exist(error);
              responseCodes.length.should.eql(50);
              _.uniq(responseCodes).should.eql([200]);

              callback(error);
            });
          });
        },
      ], done);
    });
  });

  describe('http basic auth', function() {
    it('passes the original http basic auth headers to the api backend', function(done) {
      request.get('http://foo:bar@localhost:9080/info/', this.options, function(error, response, body) {
        var data = JSON.parse(body);
        data.basic_auth_username.should.eql('foo');
        data.basic_auth_password.should.eql('bar');
        done();
      });
    });

    it('passes http basic auth added at the proxy layer to the api backend', function(done) {
      request.get('http://localhost:9080/add-auth-header/info/', this.options, function(error, response, body) {
        var data = JSON.parse(body);
        data.basic_auth_username.should.eql('somebody');
        data.basic_auth_password.should.eql('secret');
        done();
      });
    });

    it('replaces http basic auth headers passed by the client when the api backend forces its own http basic auth', function(done) {
      request.get('http://foo:bar@localhost:9080/add-auth-header/info/', this.options, function(error, response, body) {
        var data = JSON.parse(body);
        data.basic_auth_username.should.eql('somebody');
        data.basic_auth_password.should.eql('secret');
        done();
      });
    });
  });

  describe('via request header', function() {
    it('does not pass the via header header to backends', function(done) {
      request.get('http://localhost:9080/info/', this.options, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        should.not.exist(data.headers['via']);
        done();
      });
    });
  });

  describe('via response header', function() {
    it('returns the trafficserver via header, including cache decoding information, but ommitting trafficserver version and replacing the host information', function(done) {
      request.get('http://localhost:9080/info/?cache-busting=' + _.uniqueId(), this.options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        response.headers['via'].should.eql('http/1.1 api-umbrella (ApacheTrafficServer [cMsSf ])');
        done();
      });
    });

    it('appends the trafficserver via header to other via headers the backend returns', function(done) {
      request.get('http://localhost:9080/via-header/?cache-busting=' + _.uniqueId(), this.options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        response.headers['via'].should.eql('1.0 fred, 1.1 nowhere.com (Apache/1.1), http/1.1 api-umbrella (ApacheTrafficServer [cMsSf ])');
        done();
      });
    });
  });

  describe('circular requests', function() {
    it('allows an api umbrella backend server to reference the same api umbrella instance', function(done) {
      var uniqueId = _.uniqueId();
      request.get('http://localhost:9080/circular/?cache-busting=' + uniqueId, this.options, function(error, response, body) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        response.headers['via'].should.eql('http/1.1 api-umbrella (ApacheTrafficServer [cMsSf ]), http/1.1 api-umbrella (ApacheTrafficServer [cMsSf ])');
        var data = JSON.parse(body);
        data.url.path.should.eql('/info/circular-example/?cache-busting=' + uniqueId);
        done();
      });
    });
  });

  describe('long hostnames defined in "hosts" config require "nginx.server_names_hash_bucket_size" option to be adjusted', function() {
    shared.runServer({
      apis: [
        {
          frontend_host: 'abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij',
          backend_host: 'abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij',
          servers: [
            {
              host: '127.0.0.1',
              port: 9444,
            },
          ],
          url_matches: [
            {
              frontend_prefix: '/long-host-in-hosts-info/',
              backend_prefix: '/info/',
            },
          ],
        },
      ],
      hosts: [
        {
          hostname: 'abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij',
        },
      ],
      nginx: {
        server_names_hash_bucket_size: 200,
      },
    });

    it('supports long hostnames', function(done) {
      var options = _.merge({}, this.options, {
        headers: {
          'Host': 'abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij',
        },
      });

      request.get('http://localhost:9080/long-host-in-hosts-info/', options, function(error, response, body) {
        response.statusCode.should.eql(200);
        var data = JSON.parse(body);
        data.headers.host.length.should.eql(200);
        done();
      });
    });
  });
});
