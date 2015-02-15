'use strict';

var apiUmbrellaConfig = require('api-umbrella-config');

exports.start = function(options, callback) {
  apiUmbrellaConfig.setGlobal(options.config);

  var LogProcessorWorker = require('./log_processor/worker').Worker;
  var worker = new LogProcessorWorker(options);
  if(callback) {
    worker.on('ready', callback);
  }

  return worker;
};
