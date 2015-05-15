'use strict';

var _ = require('lodash'),
    url = require('url');

var RewriteResponse = function() {
  this.initialize.apply(this, arguments);
};

_.extend(RewriteResponse.prototype, {
  initialize: function() {
  },

  handleResponse: function(request, response, next) {
    // Wait until response.writeHead() is called to modify the response so we
    // can ensure that all the headers have been received, but not yet sent.
    var origWriteHead = response.writeHead;
    response.writeHead = function() {
      this.setDefaultHeaders(request, response);
      this.setOverrideHeaders(request, response);
      this.rewriteRedirects(request, response);

      return origWriteHead.apply(response, arguments);
    }.bind(this);

    next();
  },

  /* Redirects from the backend might include backend-specific urls. Hide
   * them.
   */
  rewriteRedirects: function(request, response) {
    var loc = url.parse(response.getHeader('location') || ''),
        matchedApi = request.apiUmbrellaGatekeeper.matchedApi;
    if (loc.host === matchedApi.backend_host) {
      loc.host = matchedApi.frontend_host;
      for (var i = 0, len = matchedApi.url_matches.length; i < len; i++) {
        var match = matchedApi.url_matches[i];
        if (loc.pathname && loc.pathname.indexOf(match.backend_prefix) === 0) {
          loc.pathname = loc.pathname.replace(match.backend_prefix, match.frontend_prefix);   // only replaces the first instance
        }
      }
      response.setHeader('location', url.format(loc));
    }
  },

  setDefaultHeaders: function(request, response) {
    var headers = request.apiUmbrellaGatekeeper.settings.default_response_headers;
    if(headers) {
      for(var i = 0, len = headers.length; i < len; i++) {
        var header = headers[i];
        var existingValue = response.getHeader(header.key);
        if(!existingValue) {
          response.setHeader(header.key, header.value);
        }
      }
    }
  },

  setOverrideHeaders: function(request, response) {
    var headers = request.apiUmbrellaGatekeeper.settings.override_response_headers;
    if(headers) {
      for(var i = 0, len = headers.length; i < len; i++) {
        var header = headers[i];
        response.setHeader(header.key, header.value);
      }
    }
  },
});

module.exports = function rewriteResponse() {
  var middleware = new RewriteResponse();

  return function(request, response, next) {
    middleware.handleResponse(request, response, next);
  };
};
