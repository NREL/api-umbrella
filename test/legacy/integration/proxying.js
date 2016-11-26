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
});
