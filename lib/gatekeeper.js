'use strict';

var GatekeeperWorker = require('./gatekeeper/worker').Worker;

exports.start = function(options, callback) {
  var worker = new GatekeeperWorker(options);
  if(callback) {
    worker.on('ready', callback);
  }

  return worker;
};
