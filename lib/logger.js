'use strict';

var bunyan = require('bunyan'),
    bunyanRollbar = require('bunyan-rollbar'),
    rollbar = require('./rollbar');

// Ensure the internal error serializer used by Bunyan uses the one customized
// for Rollbar.
bunyan.stdSerializers.err = bunyanRollbar.stdSerializers.err;

var logLevel = process.env.API_UMBRELLA_LOG_LEVEL || 'info';

// Log to stdout, except in the test environment where we log to a file to
// quiet the output.
var streams = [];
if(process.env.API_UMBRELLA_LOG_PATH) {
  streams.push({
    level: logLevel,
    path: process.env.API_UMBRELLA_LOG_PATH,
  });
} else {
  streams.push({
    level: logLevel,
    stream: process.stdout,
  });
}

// If rollbar is enabled, send all warning and above messages to Rollbar for
// tracking.
if(rollbar) {
  streams.push({
    level: 'warn',
    type: 'raw',
    stream: new bunyanRollbar.Stream({
      rollbar: rollbar,
    }),
  });
}

var logger = bunyan.createLogger({
  name: 'api-umbrella-router',
  serializers: bunyanRollbar.stdSerializers,
  streams: streams,
});

module.exports = logger;
