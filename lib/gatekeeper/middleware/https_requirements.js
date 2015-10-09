'use strict';

var _ = require('lodash'),
    config = require('api-umbrella-config').global(),
    url = require('url'),
    utils = require('../utils');

var HttpsRequirements = function() {
  this.initialize.apply(this, arguments);
};

_.extend(HttpsRequirements.prototype, {
  initialize: function() {
    this.httpsPort = config.get('https_port');
  },

  handleRequest: function(request, response, next) {
    if(request.base.substring(0, 8).toLowerCase() === 'https://') {
      // https requests are always okay, so continue.
      next();
    } else if(request.base.substring(0, 7).toLowerCase() !== 'http://') {
      // If this isn't an http request, then we don't know how to handle it, so
      // continue.
      next();
    } else {
      var mode = request.apiUmbrellaGatekeeper.settings.require_https;
      if(mode === 'optional') {
        // Continue if https isn't required.
        next();
      } else {
        this.handleHttpRequest(mode, request, response, next);
      }
    }
  },

  handleHttpRequest: function(mode, request, response, next) {
    var httpUrl = request.base;
    if(request.apiUmbrellaGatekeeper && request.apiUmbrellaGatekeeper.originalUrl) {
      httpUrl += request.apiUmbrellaGatekeeper.originalUrl;
    } else {
      httpUrl += request.url;
    }

    var urlParts = url.parse(httpUrl);
    urlParts.protocol = 'https:';
    delete urlParts.port;
    delete urlParts.host;
    if(this.httpsPort && this.httpsPort !== 443) {
      urlParts.port = this.httpsPort;
    }
    var httpsUrl = url.format(urlParts);

    if(mode === 'transition_return_error' || mode === 'transition_return_redirect') {
      var transitionStartAt = request.apiUmbrellaGatekeeper.settings.require_https_transition_start_at;
      var user = request.apiUmbrellaGatekeeper.user;

      // If there is no user, or the user existed prior to the HTTPS transition
      // starting, then continue on, allowing http.
      if(!user || !user.created_at || user.created_at < transitionStartAt) {
        return next();
      }
    }

    if(mode === 'required_return_redirect' || mode === 'transition_return_redirect') {
      // Return a 301 Moved Permanently redirect for GET requests.
      var statusCode = 301;

      // For non-GET requests, return a 307 Temporary Redirect, which instructs
      // the request to be made again with the same method (eg, a POST should
      // be retried as another POST). Ideally we would return a 308 Permanent
      // Redirect for permanent semantics, but that's an experimental RFC and
      // some libraries do something else currently with 308s (Resume
      // Incomplete): http://stackoverflow.com/q/14144664
      //
      // Also for general reference, see Curl's current handling of 301, 302,
      // and 303s: http://curl.haxx.se/docs/manpage.html#-L
      if(request.method !== 'GET') {
        statusCode = 307;
      }

      var headers = {
        'Access-Control-Allow-Origin': '*',
        'Location': httpsUrl,
      };

      var body;
      if(request.method !== 'HEAD') {
        body = 'Redirecting to ' + httpsUrl;
        headers['Content-Type'] = 'text/plain';
        headers['Content-Length'] = Buffer.byteLength(body);
      }

      response.writeHead(statusCode, headers);
      response.end(body);
    } else {
      utils.errorHandler(request, response, 'https_required', {
        https_url: httpsUrl,
        httpsUrl: httpsUrl,
      });
    }
  },
});

module.exports = function httpsRequirements(proxy) {
  var middleware = new HttpsRequirements(proxy);

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};
