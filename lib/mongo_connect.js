'use strict';

var config = require('./config'),
    logger = require('./logger'),
    mongoose = require('mongoose');

// Log unexpected events.
var events = ['disconnecting', 'disconnected', 'close', 'reconnected', 'error'];
events.forEach(function(event) {
  mongoose.connection.on(event, function() {
    logger.error('Mongo '+ event, arguments);
  });
});

module.exports = function(callback) {
  // Connect to mongo using mongoose.
  //
  // Note: For this application, we don't particularly need an ODM like
  // Mongoose, and the lower-level mongodb driver would meet our needs.
  // However, when using the standalone driver, we were experiencing
  // intermittent mongo connection drops in staging and production
  // environments. I can't figure out how to reproduce the original issue in a
  // testable way, so care should be taken if switching how mongo connects. See
  // here for more details: https://github.com/NREL/api-umbrella/issues/17
  mongoose.connect(config.get('mongodb'), config.get('mongodb_options'), callback);
};
