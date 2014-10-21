'use strict';

var apiUmbrellaConfig = require('api-umbrella-config');

// Ensure that url.parse(str, true) gets handled safely anywhere subsequently
// in this app.
require('./safe_url_parse');

exports.start = function(options, callback) {
  apiUmbrellaConfig.setGlobal(options.config);

  var GatekeeperWorker = require('./gatekeeper/worker').Worker;
  var worker = new GatekeeperWorker(options);
  if(callback) {
    worker.on('ready', callback);
  }

  return worker;
};
