'use strict';

var httpProxy = require('http-proxy');

module.exports.bufferRequest = function bufferRequest() {
  return function(request, response, next) {
    request.middlewareBuffer = httpProxy.buffer(request);
    next();
  };
};

module.exports.proxyBufferedRequest = function proxyBufferedRequest(proxy, httpProxy) {
  var target = proxy.config.get('proxy:target').split(':');
  var host = target[0];
  var port = parseInt(target[1]);

  return function(request, response, next) {
    httpProxy.proxyRequest(request, response, {
      host: host,
      port: port,
      buffer: request.middlewareBuffer
    });

    next();
  };
};
