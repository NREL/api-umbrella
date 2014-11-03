'use strict';

var _ = require('lodash'),
    fs = require('fs'),
    format = require('util').format,
    Log = require('log');

if(!global.rollbar) {
  global.rollbar = require('./rollbar');
}

var logLevel = process.env.API_UMBRELLA_LOG_LEVEL || 'info';
var stream = process.stdout;
if(process.env.API_UMBRELLA_LOG_PATH) {
  stream = fs.createWriteStream(process.env.API_UMBRELLA_LOG_PATH, {
    flags: 'a'
  });
}

var logger = new Log(logLevel, stream);

var originalLog = logger.log;
logger.log = function(levelStr, args) {
  var custom = args[1];
  var request;
  var errorObj;
  if(_.isPlainObject(custom)) {
    // See if a request object was passed into the second argument. In that
    // case, pull the request object out for rollbar reporting (since rollbar
    // can handle requests specially. Then for local logging purposes, simplify
    // the request data logged, since we don't want to log the full request
    // object and all its internal properties.
    if(_.isObject(custom.request) && custom.request.url) {
      request = custom.request;
      delete custom.request;
      custom.request = _.pick(request, [
        'headers',
        'ip',
        'method',
        'url',
      ]);
    }

    // Also pull  out the error object for passing to rollbar separately.
    if(_.isObject(custom.error) && (custom.error instanceof Error)) {
      errorObj = custom.error;
      delete custom.error;
      custom.error = errorObj.message;
    }
  }

  // Call the original logger to log things locally.
  var returnValue = originalLog.apply(logger, arguments);

  // If this installation has rollbar enabled and the message is WARNING or
  // above, send the details to rollbar for tracking.
  if(global.rollbar) {
    if(Log[levelStr] <= Log.WARNING) {
      var message = args[0];
      var payload = {
        level: levelStr.toLowerCase(),
      };

      if(_.isPlainObject(custom)) {
        // Delete the simplified request details from the custom object if
        // we're also sending rollbar the full request object.
        if(request) {
          delete custom.request;
        }

        // Delete the error message if we're also sending rollbar the full
        // error object.
        if(errorObj) {
          delete custom.error;
        }

        payload.custom = custom;
      } else {
        message = format.apply(null, args);
      }

      if(errorObj) {
        payload.custom = payload.custom || {};
        payload.custom.logMessage = message;
        global.rollbar.handleErrorWithPayloadData(errorObj, payload, request);
      } else {
        global.rollbar.reportMessageWithPayloadData(message, payload, request);
      }
    }
  }

  return returnValue;
};

module.exports = logger;
