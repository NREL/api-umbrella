'use strict';

var express = require('express');

var app = express();
app.use(express.bodyParser());

app.use(function(req, res, next) {
  backendCalled = true;
  next();
});

app.get('/hello', function(req, res) {
  res.send('Hello World');
});

app.post('/hello', function(req, res) {
  res.send('Goodbye');
});

app.post('/echo', function(req, res) {
  res.send(req.body);
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

app.get('/chunked', function(req, res) {
  res.write("5\r\nHello\r\n")

  setTimeout(function() {
    res.write("7\r\nGoodbye\r\n")

    setTimeout(function() {
      res.write("0\r\n\r\n")
    }, 100);
  }, 100);
});

app.listen(9444);
