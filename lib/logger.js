'use strict';

if(!global.rollbar) {
  global.rollbar = require('./rollbar');
}

var logger = require('api-umbrella-gatekeeper').wrappedLogger();
module.exports = logger;
