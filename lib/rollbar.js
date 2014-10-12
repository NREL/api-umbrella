'use strict';

var config = require('api-umbrella-config').global();

if(!config) {
  console.warn('WARNING: rollbar loaded before config is ready - unable to determine if rollbar should be enabled (rollbar.router_token config)');
  module.exports = null;
} else if(config.get('rollbar.gatekeeper_token') && ['test', 'development'].indexOf(config.get('app_env')) === -1) {
  var rollbar = require('rollbar');

  rollbar.init(config.get('rollbar.router_token'), {
    environment: config.get('app_env'),
    handler: 'setInterval',
    handlerInterval: 5,
  });

  rollbar.handleUncaughtExceptions();

  module.exports = rollbar;
} else {
  module.exports = null;
}
