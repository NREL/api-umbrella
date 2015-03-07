'use strict';

var _ = require('lodash'),
    async = require('async'),
    basicAuth = require('basic-auth-connect'),
    bodyParser = require('body-parser'),
    express = require('express'),
    url = require('url');

var app = express();
app.use(bodyParser.raw());

app.use(function(req, res, next) {
  backendCalled = true;
  next();
});

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

app.get('/chunked', function(req, res) {
  res.write('5\r\nHello\r\n');

  setTimeout(function() {
    res.write('7\r\nGoodbye\r\n');

    setTimeout(function() {
      res.write('0\r\n\r\n');
    }, 100);
  }, 100);
});

app.all('/info/*', function(req, res) {
  var rawUrl = req.protocol + '://' + req.hostname + req.url;
  res.json({
    headers: req.headers,
    raw_url: rawUrl,
    url: url.parse(rawUrl, true),
  });
});

var auth = basicAuth(function(user, pass) {
  return (user === 'somebody' && pass === 'secret') ||
    (user === 'anotheruser' && pass === 'anothersecret');
});

app.get('/auth/*', auth, function(req, res) {
  res.send(req.user);
});

app.listen(9444);
