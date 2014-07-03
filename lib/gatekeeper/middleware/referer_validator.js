'use strict';

var _ = require('lodash'),
    escapeRegexp = require('escape-regexp'),
    LRU = require('lru-cache'),
    utils = require('../utils');

var matcherCache = LRU({ max: 200 });

var RefererValidator = function() {
  this.initialize.apply(this, arguments);
};

_.extend(RefererValidator.prototype, {
  initialize: function() {
  },

  handleRequest: function(request, response, next) {
    var apiAllowedReferers = request.apiUmbrellaGatekeeper.originalApiSettings.allowed_referers;

    // IE8-9 pseudo CORS support doesn't send Referer headers, only Origin
    // headers. So fallback to that for checking (this isn't really the same
    // thing as the referer, though, so this could probably use some
    // revisiting).
    var referer = request.headers.referer || request.headers.origin;

    var allowed = true;
    var i, len;
    if(apiAllowedReferers && apiAllowedReferers.length > 0) {
      allowed = false;
      if(referer) {
        for(i = 0, len = apiAllowedReferers.length; i < len; i++) {
          if(this.refererMatches(referer, apiAllowedReferers[i])) {
            allowed = true;
            break;
          }
        }
      }
    }

    if(allowed && request.apiUmbrellaGatekeeper.originalUserSettings) {
      var userAllowedReferers = request.apiUmbrellaGatekeeper.originalUserSettings.allowed_referers;
      if(userAllowedReferers && userAllowedReferers.length > 0) {
        allowed = false;
        if(referer) {
          for(i = 0, len = userAllowedReferers.length; i < len; i++) {
            if(this.refererMatches(referer, userAllowedReferers[i])) {
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

  refererMatches: function(referer, pattern) {
    var matcher = matcherCache.get(pattern);
    if(!matcher) {
      var matcherPattern = escapeRegexp(pattern);
      matcherPattern = matcherPattern.replace(/(^|[^\\])\\\*/g, '$1.*');
      matcher = new RegExp('^' + matcherPattern + '$');
      matcherCache.set(pattern, matcher);
    }

    return matcher.test(referer);
  }
});

module.exports = function refererValidator(proxy) {
  var middleware = new RefererValidator(proxy);

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};
