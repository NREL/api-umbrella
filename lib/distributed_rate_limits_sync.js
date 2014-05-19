'use strict';

var apiUmbrellaConfig = require('api-umbrella-config');

exports.start = function(options, callback) {
  apiUmbrellaConfig.setGlobal(options.config);

  var SyncWorker = require('./distributed_rate_limits_sync/worker').Worker;
  var worker = new SyncWorker(options);
  if(callback) {
    worker.on('ready', callback);
  }

  return worker;
};
