'use strict';

var express = require('express'),
    url = require('url');

var app = express();
app.use(express.bodyParser());

app.use(function(req, res, next) {
  next();
});

app.all('/info/*', function(req, res) {
  res.json({
    headers: req.headers,
    url: url.parse(req.protocol + '://' + req.host + req.url, true),
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
