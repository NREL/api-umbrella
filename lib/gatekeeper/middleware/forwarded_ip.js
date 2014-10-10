'use strict';

var config = require('api-umbrella-config').global(),
    proxyaddr = require('proxy-addr');

module.exports = function forwardedIp() {
  var trustedProxies = config.get('router.trusted_proxies');

  return function(request, response, next) {
    request.ip = proxyaddr(request, trustedProxies);
    next();
  };
};
