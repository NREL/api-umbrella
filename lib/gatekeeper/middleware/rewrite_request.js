'use strict';

var _ = require('lodash'),
    config = require('api-umbrella-config').global(),
    url = require('url');

var RewriteRequest = function() {
  this.initialize.apply(this, arguments);
};

_.extend(RewriteRequest.prototype, {
  initialize: function() {
    this.configReload();
    config.on('change', this.configReload.bind(this));
  },

  configReload: function() {
    var stripCookies = config.get('strip_cookies');
    if(stripCookies) {
      this.stripCookieRegexes = _.map(stripCookies, function(match) {
        return new RegExp(match, 'i');
      });
    }
  },

  handleRequest: function(request, response, next) {
    // Workaround for url.parse replacing backslashes with forward slashes:
    // https://github.com/joyent/node/pull/8459 This is fixed in Node 0.12, but
    // since we're on Node 0.10, sidestep the issue by replacing backslashes
    // with their URL-encoded version (which url.parse won't flip).
    var urlString = request.url.replace(/\\/g, '%5C');

    var urlParts = url.parse(urlString, true);

    this.passApiKey(request, urlParts);
    this.setUserId(request, urlParts);
    this.setRolesHeader(request, urlParts);
    this.setHost(request);
    this.appendQueryString(request, urlParts);
    this.setHeaders(request);
    this.setHttpBasicAuth(request);
    this.stripCookies(request);
    this.fixOptionsNoBody(request);

    if(urlParts.changed) {
      delete urlParts.search;
      request.url = url.format(urlParts);
    }

    this.urlRewrites(request);

    next();
  },

  passApiKey: function(request, urlParts) {
    // DEPRECATED: We don't want to pass api keys to backends for security
    // reasons. Instead, we want to only pass the X-Api-User-Id for identifying
    // the user. But for legacy purposes, we still support passing api keys to
    // specific backends.
    var passApiKeyHeader = request.apiUmbrellaGatekeeper.settings.pass_api_key_header;
    if(passApiKeyHeader) {
      // Standardize how the api key is passed to backends, so backends only have
      // to check one place (the HTTP header).
      request.headers['X-Api-Key'] = request.apiUmbrellaGatekeeper.apiKey;
    } else {
      delete request.headers['x-api-key'];
    }

    // DEPRECATED: We don't want to pass api keys to backends (see above).
    // Passing it via the query string is even worse, since it prevents
    // caching, but again, for legacy purposes, we support passing it this way
    // for specific backends.
    var passApiKeyQueryParam = request.apiUmbrellaGatekeeper.settings.pass_api_key_query_param;
    if(passApiKeyQueryParam) {
      if(urlParts.query.api_key !== request.apiUmbrellaGatekeeper.apiKey) {
        urlParts.query.api_key = request.apiUmbrellaGatekeeper.apiKey;
        urlParts.changed = true;
      }
    } else {
      // Strip the api key from the query string, so better HTTP caching can be
      // performed (so the URL won't vary for each user).
      if(urlParts.query.api_key) {
        delete urlParts.query.api_key;
        urlParts.changed = true;
      }
    }

    // Never pass along basic auth if it's how the api key was passed in
    // (otherwise, we don't want to touch the basica auth and pass along
    // whatever it contains)..
    if(request.apiUmbrellaGatekeeper.user && request.basicAuthUsername === request.apiUmbrellaGatekeeper.apiKey) {
      delete request.headers.authorization;
    }
  },

  setUserId: function(request) {
    delete request.headers['x-api-user-id'];
    if(request.apiUmbrellaGatekeeper.user) {
      request.headers['X-Api-User-Id'] = request.apiUmbrellaGatekeeper.user._id.toString();
    }
  },

  setRolesHeader: function(request) {
    delete request.headers['x-api-roles'];
    if(request.apiUmbrellaGatekeeper.user && request.apiUmbrellaGatekeeper.user.roles && request.apiUmbrellaGatekeeper.user.roles.length > 0) {
      request.headers['X-Api-Roles'] = request.apiUmbrellaGatekeeper.user.roles.join(',');
    }
  },

  setHost: function(request) {
    var host = request.apiUmbrellaGatekeeper.matchedApi.backend_host;
    if(host) {
      var wildcardMatch = request.apiUmbrellaGatekeeper.matchedApi._frontend_host_wildcard_match;
      if(typeof wildcardMatch === 'string') {
        request.headers.Host = host.replace(/^(\*|\.)/, wildcardMatch);
      } else {
        request.headers.Host = host;
      }
    }
  },

  appendQueryString: function(request, urlParts) {
    var append = request.apiUmbrellaGatekeeper.settings.cache.append_query_object;
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
        var potentialValue = header.template(request);

        // Only set header if it evaluates to a value
        if (potentialValue && potentialValue.length > 0) {
          request.headers[header.key] = header.template(request);
        }
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

  stripCookies: function(request) {
    if(request.headers.cookie && this.stripCookieRegexes && this.stripCookieRegexes.length > 0) {
      var cookieLines = request.headers.cookie.split(/; */);
      var strippedLines = [];

      for(var i = 0, len = cookieLines.length; i < len; i++) {
        var parts = cookieLines[i].split('=', 1);
        var cookieName = parts[0];

        var strip = false;
        for(var j = 0, rLen = this.stripCookieRegexes.length; j < rLen; j++) {
          if(this.stripCookieRegexes[j].test(cookieName)) {
            strip = true;
            break;
          }
        }

        if(!strip) {
          strippedLines.push(cookieLines[i]);
        }
      }

      if(strippedLines.length > 0) {
        request.headers.cookie = strippedLines.join('; ');
      } else {
        delete request.headers.cookie;
      }
    }
  },

  fixOptionsNoBody: function(request) {
    // A workaround to prevent OPTIONS requests without a body from adding a
    // "Transfer-Encoding: chunked" header. See:
    // https://github.com/NREL/api-umbrella/issues/28
    //
    // This content-length workaround is based on what node-http-proxy 1.0 does
    // for a similar issue with DELETE requests:
    // https://github.com/nodejitsu/node-http-proxy/blob/v1.1.4/lib/http-proxy/passes/web-incoming.js#L21-L35
    //
    // The workaround for DELETEs should no longer be necessary in nodejs
    // v0.12: https://github.com/joyent/node/issues/6185 And hopefully the same
    // will go for OPTIONS: https://github.com/joyent/node/pull/7725
    if(request.method === 'OPTIONS' && !request.headers['content-length']) {
      request.headers['content-length'] = '0';
    }
  },

  urlRewrites: function(request) {
    var rewrites = request.apiUmbrellaGatekeeper.matchedApi.rewrites;
    if(rewrites) {
      for(var i = 0, len = rewrites.length; i < len; i++) {
        var rewrite = rewrites[i];
        if(rewrite.http_method === 'any' || rewrite.http_method === request.method) {
          if(rewrite.matcher_type === 'route') {
            var match = rewrite.frontend_pattern.match(request.url);
            if(match) {
              request.url = rewrite.backend_template_path(match.namedParams);
              if(rewrite.backend_template_query) {
                var escapedParams = _.mapValues(match.namedParams, encodeURIComponent);
                request.url += '?' + rewrite.backend_template_query(escapedParams);
              }
            }
          } else if(rewrite.matcher_type === 'regex') {
            request.url = request.url.replace(rewrite.frontend_regex, rewrite.backend_replacement);
          }
        }
      }
    }
  },
});

module.exports = function rewriteRequest() {
  var middleware = new RewriteRequest();

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};
