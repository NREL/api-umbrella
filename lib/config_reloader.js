'use strict';

var apiUmbrellaConfig = require('api-umbrella-config');

exports.start = function(options, callback) {
  apiUmbrellaConfig.setGlobal(options.config);

  var ReloaderWorker = require('./config_reloader/worker').Worker;
  var worker = new ReloaderWorker(options);
  if(callback) {
    worker.on('ready', callback);
  }

  return worker;
};
