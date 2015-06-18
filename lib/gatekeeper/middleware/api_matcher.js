'use strict';

var _ = require('lodash'),
    cloneDeep = require('clone'),
    config = require('api-umbrella-config').global(),
    escapeRegexp = require('escape-regexp'),
    handlebars = require('handlebars'),
    querystring = require('querystring'),
    RoutePattern = require('route-pattern'),
    url = require('url'),
    utils = require('../utils');

var ApiMatcher = function() {
  this.initialize.apply(this, arguments);
};

_.extend(ApiMatcher.prototype, {
  initialize: function() {
    this.configReload();
    config.on('change', this.configReload.bind(this));
  },

  configReload: function() {
    this.defaultFrontendHost = config.get('gatekeeper.default_frontend_host');
    var apis = config.get('internal_apis') || [];
    apis = apis.concat(config.get('apis') || []);

    this.apisByHost = {};
    this.wildcardApis = [];
    for(var i = 0; i < apis.length; i++) {
      var api = cloneDeep(apis[i]);

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
      this.configHeaderSettings(api.settings);

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
          this.configHeaderSettings(subSettings.settings);
        }
      }

      if(api.rewrites) {
        for(j = 0; j < api.rewrites.length; j++) {
          var rewrite = api.rewrites[j];
          if(rewrite.matcher_type === 'route') {
            rewrite.frontend_pattern = RoutePattern.fromString(rewrite.frontend_matcher);

            var parts = rewrite.backend_replacement.split('?');
            rewrite.backend_template_path = handlebars.compile(parts[0], { noEscape: true });
            if(parts[1]) {
              rewrite.backend_template_query = handlebars.compile(parts[1], { noEscape: true });
            }
          } else if(rewrite.matcher_type === 'regex') {
            rewrite.frontend_regex = new RegExp(rewrite.frontend_matcher, 'gi');
          }
        }
      }

      if (!api.rate_limit_bucket_name) {
        api.rate_limit_bucket_name = api.frontend_host;
      }

      this.apisByHost[api.frontend_host].push(api);

      if(api.frontend_host && api.frontend_host[0] === '*') {
        api._frontend_host_regex = new RegExp('(.*)' + escapeRegexp(api.frontend_host.slice(1)));
        this.wildcardApis.push(api);
      }
    }
  },

  configHeaderSettings: function(settings) {
    if(settings.headers) {
      for(var i = 0, len = settings.headers.length; i < len; i++) {
        var header = settings.headers[i];
        header.template = handlebars.compile(header.value);
      }
    }
  },

  configCacheSettings: function(settings) {
    settings.cache = {};

    if(settings.append_query_string) {
      settings.cache.append_query_object = querystring.parse(settings.append_query_string);
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
    utils.errorHandler(request, response, 'not_found');
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
    }

    if(!apis && this.defaultFrontendHost) {
      apis = this.apisByHost[this.defaultFrontendHost];
    }

    if(!apis) {
      apis = [];
    }

    for(var i = 0, len = this.wildcardApis.length; i < len; i++) {
      var api = this.wildcardApis[i];
      var hostMatches = host.match(api._frontend_host_regex);
      if(hostMatches) {
        api._frontend_host_wildcard_match = hostMatches[1];
        apis.push(api);
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
