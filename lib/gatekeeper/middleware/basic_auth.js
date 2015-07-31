'use strict';

module.exports = function basicAuth() {
  return function(request, response, next) {
    var authorization = request.headers.authorization;
    if(authorization) {
      var parts = authorization.split(/ +/);
      var scheme = parts[0].toLowerCase();
      var encoded = parts[1];
      if(scheme === 'basic' && encoded) {
        var decoded = new Buffer(encoded, 'base64').toString();
        var separatorIndex = decoded.indexOf(':');
        if(separatorIndex !== -1) {
          request.basicAuthUsername = decoded.substring(0, separatorIndex);
        }
      }
    }

    next();
  };
};
