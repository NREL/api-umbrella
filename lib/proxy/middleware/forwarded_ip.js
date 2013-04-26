var addr = require('addr');

module.exports = function forwardedIp(proxy) {
  var trustedProxies = proxy.config.get('trusted_proxies');

  return function(request, response, next) {
    request.ip = addr(request, trustedProxies);
    next();
  }
}
