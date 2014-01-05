'use strict';

module.exports = function basicAuth() {
  return function(request, response, next) {
    var authorization = request.headers.authorization;
    if(authorization) {
      var parts = authorization.split(' ');
      var scheme = parts[0].toLowerCase();
      if(scheme === 'basic') {
        var credentials = new Buffer(parts[1], 'base64').toString().split(':');
        request.basicAuthUsername = credentials[0];
      }
    }

    next();
  };
};
