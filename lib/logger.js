'use strict';

var fs = require('fs'),
    format = require('util').format,
    Log = require('log'),
    rollbar = require('./rollbar');

var logLevel = process.env.API_UMBRELLA_LOG_LEVEL || 'info';
var stream = process.stdout;
if(process.env.API_UMBRELLA_LOG_PATH) {
  stream = fs.createWriteStream(process.env.API_UMBRELLA_LOG_PATH, {
    flags: 'a'
  });
}

var logger = new Log(logLevel, stream);

if(rollbar) {
  var originalLog = logger.log;
  logger.log = function(levelStr, args) {
    var returnValue = originalLog.apply(logger, arguments);

    if(Log[levelStr] <= Log.WARNING) {
      var message = format.apply(null, args);
      rollbar.reportMessage(message, levelStr.toLowerCase());
    }

    return returnValue;
  };
}

module.exports = logger;
