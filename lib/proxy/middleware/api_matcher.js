'use strict';

var _ = require('underscore'),
    clone = require('clone'),
    config = require('../../config'),
    handlebars = require('handlebars'),
    i18n = require('i18n'),
    querystring = require('querystring'),
    RoutePattern = require('route-pattern'),
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
    var apis = config.get('apis') || [];

    this.apisByHost = {};
    for(var i = 0; i < apis.length; i++) {
      var api = clone(apis[i]);

      if(!this.apisByHost[api.frontend_host]) {
        this.apisByHost[api.frontend_host] = [];
      }

      var j;
      if(api.url_matches) {
        for(j = 0; j < api.url_matches.length; j++) {
          var urlMatch = api.url_matches[j];
          urlMatch.frontend_prefix_regex = new RegExp('^' + urlMatch.frontend_prefix);
        }
      }

      if(!api.settings) {
        api.settings = {};
      }

      this.configCacheSettings(api.settings);

      if(api.sub_settings) {
        for(j = 0; j < api.sub_settings.length; j++) {
          var subSettings = api.sub_settings[j];
          subSettings.regex = new RegExp(subSettings.regex);

          for(var setting in subSettings.settings) {
            if(subSettings.settings[setting] === null || subSettings.settings[setting] === undefined) {
              delete subSettings.settings[setting];
            }
          }

          this.configCacheSettings(subSettings.settings);
        }
      }

      if(api.rewrites) {
        for(j = 0; j < api.rewrites.length; j++) {
          var rewrite = api.rewrites[j];
          if(rewrite.matcher_type === 'route') {
            rewrite.frontend_pattern = RoutePattern.fromString(rewrite.frontend_matcher);
            rewrite.backend_template = handlebars.compile(rewrite.backend_replacement);
          } else if(rewrite.matcher_type === 'regex') {
            rewrite.frontend_regex = new RegExp(rewrite.frontend_matcher, 'gi');
          }
        }
      }

      this.apisByHost[api.frontend_host].push(api);
    }
  },

  configCacheSettings: function(settings) {
    if(settings.append_query_string) {
      settings.append_query_object = querystring.parse(settings.append_query_string);
    }
  },

  handleRequest: function(request, response, next) {
    var apis = this.getApisForRequestHost(request);

    for(var i = 0, apisLen = apis.length; i < apisLen; i++) {
      var api = apis[i];

      if(api.url_matches) {
        for(var j = 0, matchesLen = api.url_matches.length; j < matchesLen; j++) {
          var urlMatch = api.url_matches[j];
          if(request.url.indexOf(urlMatch.frontend_prefix) === 0) {
            request.apiUmbrellaGatekeeper = {};
            request.apiUmbrellaGatekeeper.matchedApi = api;
            request.apiUmbrellaGatekeeper.originalUrl = request.url;

            request.headers['X-Api-Umbrella-Backend-Scheme'] = api.backend_protocol || 'http';
            request.headers['X-Api-Umbrella-Backend-Id'] = api._id;
            request.url = request.url.replace(urlMatch.frontend_prefix_regex, urlMatch.backend_prefix);

            next();
            return;
          }
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
