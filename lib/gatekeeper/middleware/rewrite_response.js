'use strict';

var _ = require('lodash');

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
    var original = response.getHeader('location'),
        frontend = request.apiUmbrellaGatekeeper.matchedApi.frontend_host,
        backend = request.apiUmbrellaGatekeeper.matchedApi.backend_host;
    if (original) {
      response.setHeader('location', original.replace(backend, frontend));
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
