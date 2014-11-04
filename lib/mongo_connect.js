'use strict';

var logger = require('./logger'),
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

  // Connect to mongo using mongoose.
  //
  // Note: For this application, we don't particularly need an ODM like
  // Mongoose, and the lower-level mongodb driver would meet our needs.
  // However, when using the standalone driver, we were experiencing
  // intermittent mongo connection drops in staging and production
  // environments. I can't figure out how to reproduce the original issue in a
  // testable way, so care should be taken if switching how mongo connects. See
  // here for more details: https://github.com/NREL/api-umbrella/issues/17
  mongoose.connect(config.get('mongodb.url'), config.get('mongodb.options'), callback);
};
