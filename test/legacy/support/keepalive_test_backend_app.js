'use strict';

var express = require('express');

[9445, 9446, 9447].forEach(function(port) {
  var openConnections = 0;
  var openRequests = 0;

  var app = express();

  app.use(function(req, res, next) {
    openRequests++;

    req.on('end', function() {
      openRequests--;
    });

    next();
  });

  app.get('/keepalive' + port + '/connections', function(req, res) {
    var connections = { connections: openConnections, requests: openRequests };

    // Delay sending the response so we can ensure that multiple concurrent
    // requests get opened up.
    setTimeout(function() {
      res.json(connections);
    }, 200);
  });

  var server = app.listen(port);

  server.on('connection', function(socket) {
    openConnections++;

    socket.on('close', function() {
      openConnections--;
    });
  });
});
