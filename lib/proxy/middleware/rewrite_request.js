'use strict';

var _ = require('underscore'),
    url = require('url');

var RewriteRequest = function() {
  this.initialize.apply(this, arguments);
};

_.extend(RewriteRequest.prototype, {
  initialize: function() {
  },

  handleRequest: function(request, response, next) {
    var urlParts = url.parse(request.url, true);

    this.normalizeApiKey(request, urlParts);
    this.appendQueryString(request, urlParts);
    this.setHeaders(request);
    this.setHttpBasicAuth(request);

    if(urlParts.changed) {
      delete urlParts.search;
      request.url = url.format(urlParts);
    }

    next();
  },

  normalizeApiKey: function(request, urlParts) {
    // Standardize how the api key is passed to backends, so backends only have
    // to check one place (the HTTP header).
    request.headers['X-Api-Key'] = request.apiUmbrellaGatekeeper.apiKey;

    // Strip the api key from the query string, so better HTTP caching can be
    // performed (so the URL won't vary for each user).
    if(urlParts.query.api_key) {
      delete urlParts.query.api_key;
      urlParts.changed = true;
    }
  },

  appendQueryString: function(request, urlParts) {
    var append = request.apiUmbrellaGatekeeper.settings.append_query_object;
    if(append) {
      _.extend(urlParts.query, append);
      urlParts.changed = true;
    }
  },

  setHeaders: function(request) {
    var headers = request.apiUmbrellaGatekeeper.settings.headers;
    if(headers) {
      for(var i = 0, len = headers.length; i < len; i++) {
        var header = headers[i];
        request.headers[header.key] = header.value;
      }
    }
  },

  setHttpBasicAuth: function(request) {
    var auth = request.apiUmbrellaGatekeeper.settings.http_basic_auth;
    if(auth) {
      var base64 = (new Buffer(auth, 'ascii')).toString('base64');
      request.headers.Authorization = 'Basic ' + base64;
    }
  },
});


module.exports = function rewriteRequest() {
  var middleware = new RewriteRequest();

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};
