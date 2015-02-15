'use strict';

var async = require('async'),
    logger = require('./logger'),
    mongoose = require('mongoose');

// Log unexpected events.
var events = ['disconnecting', 'disconnected', 'close', 'reconnected', 'error'];
events.forEach(function(event) {
  mongoose.connection.on(event, function(error) {
    var logEvent = true;

    if(event === 'disconnecting') {
      mongoose.expectedCloseInProgress = true;
    }

    if(mongoose.expectedCloseInProgress) {
      if(event === 'disconnecting' || event === 'disconnected' || event === 'close') {
        logEvent = false;
      }
    }

    if(event === 'close') {
      mongoose.expectedCloseInProgress = false;
    }

    if(logEvent) {
      logger.error({ err: error }, 'Mongo event: ' + event);
    }
  });
});

module.exports = function(callback) {
  var config = require('api-umbrella-config').global();

  var connected = false;
  var attempts = 0;
  var attemptDelay = 500;
  var maxAttempts = 60;
  var lastError;
  async.until(function() {
    return connected || attempts > maxAttempts;
  }, function(untilCallback) {
    mongoose.connect(config.get('mongodb.url'), config.get('mongodb.options'), function(error) {
      attempts++;
      if(!error) {
        connected = true;
        lastError = null;
        untilCallback();
      } else {
        lastError = error;
        setTimeout(untilCallback, attemptDelay);
      }
    });
  }, function() {
    callback(lastError);
  });
};
