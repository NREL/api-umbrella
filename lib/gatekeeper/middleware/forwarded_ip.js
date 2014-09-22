'use strict';

var addr = require('addr'),
    config = require('api-umbrella-config').global();

module.exports = function forwardedIp() {
  var trustedProxies = config.get('trustedProxies');

  return function(request, response, next) {
    request.ip = addr(request, trustedProxies);
    next();
  };
};
