'use strict';

var bodyParser = require('body-parser'),
    express = require('express'),
    fs = require('fs'),
    multer = require('multer'),
    path = require('path'),
    randomstring = require('randomstring'),
    url = require('url'),
    zlib = require('zlib');

var app = express();

app.use(bodyParser.raw());
app.use(multer({
  dest: path.resolve(__dirname, '../tmp'),
  onFileUploadComplete: function(file) {
    fs.unlinkSync(file.path);
  },
}));

app.all('/info/*', function(req, res) {
  res.json({
    headers: req.headers,
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
  zlib.gzip('Hello Small World', function(error, data) {
    res.end(data);
  });
});

app.get('/delay/:milliseconds', function(req, res) {
  var time = parseInt(req.params.milliseconds);
  setTimeout(function() {
    res.end('done');
  }, time);
});

app.get('/delays/:delay1/:delay2', function(req, res) {
  var delay1 = parseInt(req.params.delay1);
  var delay2 = parseInt(req.params.delay2);

  setTimeout(function() {
    res.write('first');
  }, delay1);

  setTimeout(function() {
    res.end('done');
  }, delay2);
});

app.listen(9444);
