var addr = require('addr');

module.exports = function forwardedIp(server) {
  var trustedProxies = server.config.get('trusted_proxies');

  return function(request, response, next) {
    request.ip = addr(request, trustedProxies);
    next();
  }
}
