'use strict';

var config = require('api-umbrella-config'),
    GatekeeperWorker = require('./gatekeeper/worker').Worker,
    path = require('path');

exports.start = function(options, callback) {
  config.setFiles([
    path.resolve(__dirname, '../config/default.yml'),
    options.config,
  ]);

  var worker = new GatekeeperWorker(options);
  if(callback) {
    worker.on('ready', callback);
  }

  return worker;
};
