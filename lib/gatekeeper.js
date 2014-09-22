'use strict';

var apiUmbrellaConfig = require('api-umbrella-config');

exports.start = function(options, callback) {
  apiUmbrellaConfig.setGlobal(options.config);

  var GatekeeperWorker = require('./gatekeeper/worker').Worker;
  var worker = new GatekeeperWorker(options);
  if(callback) {
    worker.on('ready', callback);
  }

  return worker;
};
