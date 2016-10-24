'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    execFile = require('child_process').execFile,
    Factory = require('factory-lady'),
    http = require('http'),
    request = require('request'),
    temp = require('temp'),
    zlib = require('zlib');

temp.track();

describe('proxying', function() {
  shared.runServer({
    apis: [
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
  });

  describe('header size', function() {
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
