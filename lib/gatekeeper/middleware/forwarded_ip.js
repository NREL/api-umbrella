'use strict';

var addr = require('addr'),
    config = require('../../config');

module.exports = function forwardedIp() {
  var trustedProxies = config.get('trustedProxies');

  return function(request, response, next) {
    request.ip = addr(request, trustedProxies);
    next();
  };
};
