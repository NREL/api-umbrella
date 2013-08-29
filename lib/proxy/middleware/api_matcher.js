'use strict';

var _ = require('underscore'),
    config = require('../../config'),
    i18n = require('i18n'),
    url = require('url');

var ApiMatcher = function() {
  this.initialize.apply(this, arguments);
};

_.extend(ApiMatcher.prototype, {
  initialize: function() {
    this.configReload();
    config.on('reload', this.configReload.bind(this));
  },

  configReload: function() {
    this.defaultFrontendHost = config.get('defaultFrontendHost');
    var apis = config.get('apis');

    this.apisByHost = {};
    for(var i = 0; i < apis.length; i++) {
      var api = apis[i];

      if(!this.apisByHost[api.frontend_host]) {
        this.apisByHost[api.frontend_host] = [];
      }

      for(var j = 0; j < api.url_matches.length; j++) {
        var urlMatch = api.url_matches[j];
        urlMatch.frontend_prefix_regex = new RegExp('^' + urlMatch.frontend_prefix);
      }

      this.apisByHost[api.frontend_host].push(api);
    }
  },

  handleRequest: function(request, response, next) {
    var apis = this.getApisForRequestHost(request);

    for(var i = 0, apisLen = apis.length; i < apisLen; i++) {
      var api = apis[i];

      for(var j = 0, matchesLen = api.url_matches.length; j < matchesLen; j++) {
        var urlMatch = api.url_matches[j];
        if(request.url.indexOf(urlMatch.frontend_prefix) === 0) {
          request.headers['X-Api-Umbrella-Backend-Scheme'] = 'http';
          request.headers['X-Api-Umbrella-Backend-Id'] = api.id;
          request.url = request.url.replace(urlMatch.frontend_prefix_regex, urlMatch.backend_prefix);

          next();
          return;
        }
      }
    }

    // If we got here, no API was matched.
    response.statusCode = 404;
    response.end(i18n.__('api_not_found'));
  },

  getApisForRequestHost: function(request) {
    var host = request.headers.host;
    var apis = this.apisByHost[host];
    if(!apis) {
      if(host) {
        if(host.indexOf(':') !== -1) {
          var hostname = host.split(':')[0];
          apis = this.apisByHost[hostname];
        } else {
          var parts = url.parse(request.base);
          var port = parts.port;
          if(!port) {
            port = (parts.protocol === 'https:') ? 443 : 80;
          }

          var hostDefaultPort = host + ':' + port;
          apis = this.apisByHost[hostDefaultPort];
        }
      }

      if(!apis) {
        apis = this.apisByHost[this.defaultFrontendHost];
      }

      if(!apis) {
        apis = [];
      }
    }

    return apis;
  },
});

module.exports = function apiMatcher() {
  var middleware = new ApiMatcher();

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};
