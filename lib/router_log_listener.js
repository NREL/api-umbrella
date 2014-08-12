'use strict';

var apiUmbrellaConfig = require('api-umbrella-config');

exports.start = function(options, callback) {
  apiUmbrellaConfig.setGlobal(options.config);

  var RouterLogListenerWorker = require('./router_log_listener/worker').Worker;
  var worker = new RouterLogListenerWorker(options);
  if(callback) {
    worker.on('ready', callback);
  }

  return worker;
};
