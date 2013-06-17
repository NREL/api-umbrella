var geoip = undefined,
    moment = require('moment'),
    url = require('url'),
    uaParser = require('uas-parser');

module.exports = function(log) {
  // Don't require geoip until after the config is read in, so we have an
  // opportunity to set a custom global.geodatadir.
  if(!geoip) {
    geoip = require('geoip-lite');
  }

  if(log.request_ip) {
    var geo = geoip.lookup(log.request_ip);
    if(geo) {
      if(geo.country) {
        log.request_ip_country = geo.country;
      }

      if(geo.region) {
        log.request_ip_region = geo.region;
      }

      if(geo.city) {
        log.request_ip_city = geo.city;
      }

      if(geo.ll) {
        log.request_ip_location = {
          lat: geo.ll[0],
          lon: geo.ll[1],
        };
      }
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
    var agent = uaParser.lookup(log.request_user_agent);
    log.request_user_agent_type = agent.type;
    log.request_user_agent_family = agent.uaFamily;

    if(!log.request_user_agent_family || log.request_user_agent_family == 'unknown') {
      var matches = log.request_user_agent.match(/^([^/\s]+)/);
      if(matches && matches[1] != 'Mozilla') {
        log.request_user_agent_family = matches[1];
      }
    }

    if(!log.request_user_agent_type || log.request_user_agent_type == 'unknown') {
      log.request_user_agent_type = null;
    }

    if(!log.request_user_agent_family || log.request_user_agent_family == 'unknown') {
      log.request_user_agent_family = null;
    }
  }

  return log;
}
