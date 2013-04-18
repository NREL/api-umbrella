var httpProxy = require('http-proxy');

module.exports.bufferRequest = function bufferRequest() {
  return function(request, response, next) {
    request.middlewareBuffer = httpProxy.buffer(request);
    next();
  }
}

module.exports.proxyBufferedRequest = function proxyBufferedRequest(server, proxy) {
  var backend = server.config.get('backend').split(':');
  var host = backend[0];
  var port = parseInt(backend[1]);

  return function(request, response, next) {
    proxy.proxyRequest(request, response, {
      host: backend[0],
      port: parseInt(backend[1]),
      buffer: request.middlewareBuffer
    });

    next();
  }
}
