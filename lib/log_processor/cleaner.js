var geoip = undefined,
    moment = require('moment'),
    url = require('url'),
    useragent = require('useragent');

module.exports = function(log) {
  // Don't require geoip until after the config is read in, so we have an
  // opportunity to set a custom global.geodatadir.
  if(!geoip) {
    geoip = require('geoip-lite');
  }

  if(log.request_ip) {
    var geo = geoip.lookup(log.request_ip);
    if(geo) {
      log.request_ip_country = geo.country;
      log.request_ip_region = geo.region;
      log.request_ip_city = geo.city;
      log.request_ip_location = {
        lat: geo.ll[0],
        lon: geo.ll[1],
      };
    }
  }

  var urlParts = url.parse(log.request_url, true);
  log.request_path = urlParts.pathname.replace(/\.\w+$/, '');

  if(log.request_url.indexOf("api_key") != -1) {
    delete urlParts.search;
    delete urlParts.query.api_key;
    log.request_url = url.format(urlParts);
  }

  if(log.request_user_agent) {
    var agent = useragent.parse(log.request_user_agent);
    log.request_user_agent_family = agent.family;

    if(log.request_user_agent_family == "Other") {
      var matches = log.request_user_agent.match(/^([^/\s]+)/);
      if(matches) {
        log.request_user_agent_family = matches[1];
      }
    }
  }

  return log;
}
