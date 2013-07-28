var utils = require('connect').utils,
    url = require('url');

module.exports = function forwardedIp(proxy) {
  var trustedProxies = proxy.config.get('trusted_proxies');

  return function(request, response, next) {
    // Standardize how the api key is passed to backends, so backends only have
    // to check one place (the HTTP header).
    request.headers['x-api-key'] = request.apiUmbrellaGatekeeper.apiKey
    if(request.query.api_key) {
      var urlParts = utils.parseUrl(request);
      urlParts.query = request.query;

      // Strip the api key from the query string, so better HTTP caching can be
      // performed (so the URL won't vary for each user).
      delete urlParts.search;
      delete urlParts.query.api_key;
      request.url = url.format(urlParts);
    }

    next();
  }
}
