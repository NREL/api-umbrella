'use strict';

var _ = require('lodash'),
    ipaddr = require('ipaddr.js'),
    utils = require('../utils');

var IpValidator = function() {
  this.initialize.apply(this, arguments);
};

_.extend(IpValidator.prototype, {
  initialize: function() {
  },

  handleRequest: function(request, response, next) {
    var apiAllowedIps = request.apiUmbrellaGatekeeper.originalApiSettings.allowed_ips;

    var allowed = true;
    var i, len;
    if(apiAllowedIps && apiAllowedIps.length > 0) {
      allowed = false;
      if(request.ip) {
        for(i = 0, len = apiAllowedIps.length; i < len; i++) {
          if(this.ipMatches(request.ip, apiAllowedIps[i])) {
            allowed = true;
            break;
          }
        }
      }
    }

    if(allowed && request.apiUmbrellaGatekeeper.originalUserSettings) {
      var userAllowedIps = request.apiUmbrellaGatekeeper.originalUserSettings.allowed_ips;
      if(userAllowedIps && userAllowedIps.length > 0) {
        allowed = false;
        if(request.ip) {
          for(i = 0, len = userAllowedIps.length; i < len; i++) {
            if(this.ipMatches(request.ip, userAllowedIps[i])) {
              allowed = true;
              break;
            }
          }
        }
      }
    }

    if(allowed) {
      next();
    } else {
      utils.errorHandler(request, response, 'api_key_unauthorized');
    }
  },

  ipMatches: function(ipString, rangeString) {
    var matches = false;

    var rangeData = rangeString.split('/');
    var rangeIpString = rangeData[0];
    if(ipaddr.isValid(ipString) && ipaddr.isValid(rangeIpString)) {
      var ip = ipaddr.parse(ipString);
      var range = ipaddr.parse(rangeIpString);

      if(ip.kind() === range.kind()) {
        var rangeSize = parseInt(rangeData[1], 10);
        matches = ip.match(range, rangeSize);
      }
    }

    return matches;
  },
});

module.exports = function ipValidator(proxy) {
  var middleware = new IpValidator(proxy);

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};
