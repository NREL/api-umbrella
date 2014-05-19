'use strict';

var config = require('api-umbrella-config').global(),
    httpProxy = require('http-proxy');

module.exports.bufferRequest = function bufferRequest() {
  return function(request, response, next) {
    request.middlewareBuffer = httpProxy.buffer(request);
    next();
  };
};

module.exports.proxyBufferedRequest = function proxyBufferedRequest(httpProxy) {
  var target = config.get('proxy.target').split(':');
  var host = target[0];
  var port = parseInt(target[1], 10);

  return function(request, response, next) {
    httpProxy.proxyRequest(request, response, {
      host: host,
      port: port,
      buffer: request.middlewareBuffer
    });

    next();
  };
};
