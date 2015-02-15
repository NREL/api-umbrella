'use strict';

<<<<<<< HEAD


=======
var _ = require('lodash'),
    async = require('async'),
    basicAuth = require('basic-auth-connect'),
    bodyParser = require('body-parser'),
    compression = require('compression'),
    express = require('express'),
    fs = require('fs'),
    multer = require('multer'),
    path = require('path'),
    randomstring = require('randomstring'),
    url = require('url'),
    zlib = require('zlib');

// Ensure that url.parse(str, true) gets handled safely anywhere subsequently
// in this app.
require('./safe_url_parse');

global.backendCallCounts = {};

function incrementCachableCallCount(id) {
  global.backendCallCounts[id] = global.backendCallCounts[id] || 0;
  global.backendCallCounts[id]++;
}

function uniqueOutput() {
  return process.hrtime().join('-') + '-' + Math.random();
}

var app = express();

app.use(bodyParser.raw());
app.use(function(req, res, next) {
  backendCalled = true;
  next();
});
app.use(multer({
  dest: path.resolve(__dirname, '../tmp'),
  onFileUploadComplete: function(file) {
    fs.unlinkSync(file.path);
  },
}));

app.get('/hello', function(req, res) {
  res.send('Hello World');
});

app.get('/hello/*', function(req, res) {
  res.send('Hello World');
});

app.post('/hello', function(req, res) {
  res.send('Goodbye');
});

app.post('/echo', function(req, res) {
  res.send(req.body);
});

app.get('/echo_delayed_chunked', function(req, res) {
  var parts = req.query.input.split('');
  async.eachSeries(parts, function(part, next) {
    setTimeout(function() {
      res.write(part);
      next();
    }, _.random(5, 15));
  }, function() {
    setTimeout(function() {
      res.end('');
    }, _.random(5, 15));
  });
});

app.get('/restricted', function(req, res) {
  res.send('Restricted Access');
});

app.get('/not/restricted', function(req, res) {
  res.send('Not Restricted');
});

app.get('/utf8', function(req, res) {
  res.set('X-Example', 'tést');
  res.send('Hellö Wörld');
});

app.get('/sleep', function(req, res) {
  setTimeout(function() {
    res.send('Sleepy head');
  }, 1000);
});

app.get('/sleep_timeout', function(req, res) {
  setTimeout(function() {
    res.send('Sleepy head');
  }, 2000);
});

var auth = basicAuth(function(user, pass) {
  return (user === 'somebody' && pass === 'secret') ||
    (user === 'anotheruser' && pass === 'anothersecret');
});

app.get('/auth/*', auth, function(req, res) {
  res.send(req.user);
});

app.all('/info/*', function(req, res) {
  res.set('X-Received-Method', req.method);
  res.json({
    method: req.method,
    headers: req.headers,
    local_interface_ip: req.socket.localAddress,
    url: url.parse(req.protocol + '://' + req.hostname + req.url, true),
  });
});

app.post('/upload', function(req, res) {
  res.json({
    upload_size: req.files.upload.size,
  });
});

app.get('/chunked', function(req, res) {
  res.write('hello');
  setTimeout(function() {
    res.write('salutations');
    setTimeout(function() {
      res.write('goodbye');
      res.end();
    }, 500);
  }, 500);
});

app.post('/receive_chunks', function(req, res) {
  var chunks = [];
  var chunkTimeGaps = [];
  var lastChunkTime;
  req.on('data', function(chunk) {
    chunks.push(chunk.toString());

    if(lastChunkTime) {
      var gap = Date.now() - lastChunkTime;
      chunkTimeGaps.push(gap);
    }

    lastChunkTime = Date.now();
  });

  req.on('end', function() {
    res.json({
      request_encoding: req.header('Transfer-Encoding'),
      chunks: chunks,
      chunkTimeGaps: chunkTimeGaps,
    });
  });
});

app.get('/compressible/:size', function(req, res) {
  var size = parseInt(req.params.size);
  var contentType = (req.query.content_type === undefined) ? 'text/plain' : req.query.content_type;
  res.set('Content-Type', contentType);
  res.set('Content-Length', size);
  res.end(randomstring.generate(size));
});

app.get('/compressible-chunked/:chunks/:size', function(req, res) {
  var contentType = (req.query.content_type === undefined) ? 'text/plain' : req.query.content_type;
  var chunks = parseInt(req.params.chunks);
  var size = parseInt(req.params.size);

  res.set('Content-Type', contentType);
  setTimeout(function() {
    for(var i = 0; i < chunks; i++) {
      res.write(randomstring.generate(size));
    }
    res.end();
  }, 50);
});

app.get('/compressible-delayed-chunked/:size', function(req, res) {
  var size = parseInt(req.params.size);
  res.set('Content-Type', 'text/plain');
  res.write(randomstring.generate(size));
  setTimeout(function() {
    res.write(randomstring.generate(size));
    setTimeout(function() {
      res.write(randomstring.generate(size));
      res.end();
    }, 500);
  }, 500);
});

app.get('/compressible-pre-gzip', function(req, res) {
  res.set('Content-Type', 'text/plain');
  res.set('Content-Encoding', 'gzip');
  res.set('Vary', 'Accept-Encoding');
  zlib.gzip('Hello Small World', function(error, data) {
    res.end(data);
  });
});

app.all('/delay/:milliseconds', function(req, res) {
  var time = parseInt(req.params.milliseconds);
  setTimeout(function() {
    res.end('done');
  }, time);
});

app.all('/delays/:delay1/:delay2', function(req, res) {
  var delay1 = parseInt(req.params.delay1);
  var delay2 = parseInt(req.params.delay2);

  setTimeout(function() {
    res.write('first');
  }, delay1);

  setTimeout(function() {
    res.end('done');
  }, delay2);
});

app.get('/timeout', function(req, res) {
  incrementCachableCallCount('get-timeout');
  setTimeout(function() {
    res.end('done');
  }, 70000);
});

app.post('/timeout', function(req, res) {
  incrementCachableCallCount('post-timeout');
  setTimeout(function() {
    res.end('done');
  }, 70000);
});

app.get('/between-varnish-timeout', function(req, res) {
  incrementCachableCallCount('post-between-varnish-timeout');
  setTimeout(function() {
    res.end('done');
  }, 62500);
});

app.all('/cacheable-but-not/:id', function(req, res) {
  res.end(uniqueOutput());
});

app.all('/cacheable-thundering-herd/:id', function(req, res) {
  incrementCachableCallCount(req.params.id);

  setTimeout(function() {
    res.set('Cache-Control', 'max-age=60');
    res.end(uniqueOutput());
  }, 1000);
});

app.all('/cacheable-but-no-explicit-cache-thundering-herd/:id', function(req, res) {
  incrementCachableCallCount(req.params.id);

  setTimeout(function() {
    res.set('Cache-Control', 'max-age=0, private, must-revalidate');
    res.end(uniqueOutput());
  }, 1000);
});

app.all('/cacheable-but-cache-forbidden-thundering-herd/:id', function(req, res) {
  incrementCachableCallCount(req.params.id);

  setTimeout(function() {
    res.set('Cache-Control', 'max-age=0, private, must-revalidate');
    res.end(uniqueOutput());
  }, 1000);
});

app.all('/cacheable-cache-control-max-age/:id', function(req, res) {
  res.set('Cache-Control', 'max-age=60');
  res.set('X-Unique-Output', uniqueOutput());
  res.end(uniqueOutput());
});

app.all('/cacheable-cache-control-s-maxage/:id', function(req, res) {
  res.set('Cache-Control', 's-maxage=60');
  res.end(uniqueOutput());
});

app.all('/cacheable-cache-control-case-insensitive/:id', function(req, res) {
  res.set('CAcHE-cONTROL', 'max-age=60');
  res.end(uniqueOutput());
});

app.all('/cacheable-expires/:id', function(req, res) {
  res.set('Expires', new Date(Date.now() + 60000).toUTCString());
  res.end(uniqueOutput());
});

app.all('/cacheable-expires-0/:id', function(req, res) {
  res.set('Expires', '0');
  res.end(uniqueOutput());
});

app.all('/cacheable-expires-past/:id', function(req, res) {
  res.set('Expires', new Date(Date.now() - 60000).toUTCString());
  res.end(uniqueOutput());
});

app.all('/cacheable-set-cookie/:id', function(req, res) {
  res.set('Cache-Control', 'max-age=60');
  res.set('Set-Cookie', 'foo=bar');
  res.end(uniqueOutput());
});

app.all('/cacheable-www-authenticate/:id', function(req, res) {
  res.set('Cache-Control', 'max-age=60');
  res.set('WWW-Authenticate', 'Basic');
  res.end(uniqueOutput());
});

app.all('/cacheable-surrogate-control-max-age/:id', function(req, res) {
  res.set('Surrogate-Control', 'max-age=60');
  res.end(uniqueOutput());
});

app.all('/cacheable-surrogate-control-case-insensitive/:id', function(req, res) {
  res.set('SURrOGATE-CONtROL', 'max-age=60');
  res.end(uniqueOutput());
});

app.all('/cacheable-surrogate-control-and-cache-control/:id', function(req, res) {
  res.set('Surrogate-Control', 'max-age=60');
  res.set('Cache-Control', 'max-age=0, private, must-revalidate');
  res.end(uniqueOutput());
});

app.all('/cacheable-dynamic/*', function(req, res) {
  res.set('Cache-Control', 'max-age=60');
  res.end(uniqueOutput());
});

app.all('/cacheable-compressible/:id', function(req, res) {
  res.set('Cache-Control', 'max-age=60');
  res.set('Content-Type', 'text/plain');
  res.end(uniqueOutput() + randomstring.generate(1500));
});

app.all('/cacheable-pre-gzip/:id', compression(), function(req, res) {
  res.set('Cache-Control', 'max-age=60');
  res.set('Content-Type', 'text/plain');
  res.end(uniqueOutput() + randomstring.generate(1500));
});

app.all('/cacheable-vary-accept-encoding/:id', function(req, res) {
  res.set('Cache-Control', 'max-age=60');
  res.set('Content-Type', 'text/plain');
  res.set('Vary', 'Accept-Encoding');
  res.end(uniqueOutput() + randomstring.generate(1500));
});

app.all('/cacheable-pre-gzip-multiple-vary/:id', compression(), function(req, res) {
  res.set('Cache-Control', 'max-age=60');
  res.set('Content-Type', 'text/plain');
  res.set('Vary', 'X-Foo,Accept-Encoding,Accept');
  res.end(uniqueOutput() + randomstring.generate(1500));
});

app.all('/cacheable-vary-accept-encoding-multiple/:id', function(req, res) {
  res.set('Cache-Control', 'max-age=60');
  res.set('Content-Type', 'text/plain');
  res.set('Vary', 'X-Foo,Accept-Encoding,Accept');
  res.end(uniqueOutput() + randomstring.generate(1500));
});

app.all('/cacheable-vary-x-custom/:id', function(req, res) {
  res.set('Cache-Control', 'max-age=60');
  res.set('Vary', 'X-Custom');
  res.end(uniqueOutput());
});

app.all('/cacheable-vary-accept-encoding-accept-separate/:id', function(req, res) {
  res.set('Cache-Control', 'max-age=60');
  res.set('Vary', 'Accept-Encoding');
  res.set('Vary', 'Accept');
  res.end(uniqueOutput());
});

app.all('/cacheable-multiple-vary/:id', function(req, res) {
  res.set('Cache-Control', 'max-age=60');
  res.set('Content-Type', 'text/plain');
  res.set('Vary', 'X-Foo,Accept-Language,Accept');
  res.end(uniqueOutput());
});

app.all('/cacheable-multiple-vary-with-accept-encoding/:id', function(req, res) {
  res.set('Cache-Control', 'max-age=60');
  res.set('Content-Type', 'text/plain');
  res.set('Vary', 'X-Foo,Accept-Language,Accept-Encoding,Accept');
  res.end(uniqueOutput() + randomstring.generate(1500));
});

app.all('/logging-example/*', function(req, res) {
  res.set('Age', '20');
  res.set('Cache-Control', 'max-age=60');
  res.set('Content-Type', 'text/plain');
  res.set('Expires', new Date(Date.now() + 60000).toUTCString());
  res.set('Content-Length', 5);
  res.end('hello');
});

// Listen on all interfaces on both IPv4 and IPv6
['0.0.0.0', '::1'].forEach(function(host) {
  var server = app.listen(9444, host);
  server.on('error', function(error) {
    console.error('Failed to start example backend app (' + host + '):', error);
    if(host === '::1') {
      global.DISABLE_IPV6_TESTS = true;
      console.error('Could not start backend app on IPv6 address - Disabling IPv6 tests');
    } else {
      process.exit(1);
    }
  });
});
>>>>>>> router/master
