'use strict';

var crypto = require('crypto'),
    logger = require('../logger'),
    moment = require('moment'),
    url = require('url'),
    uaParser = require('uas-parser');

// Don't require geoip until after the config is read in, so we have an
// opportunity to set a custom global.geodatadir.
require('../config');
var geoip = require('geoip-lite');

// Cache the last geocoded location for each city in a separate index. When
// faceting by city names on the log index (for displaying on a map), there
// doesn't appear to be an easy way to fetch the associated locations for each
// city facet. This allows us to perform a separate lookup to fetch the
// pre-geocoded locations for each city.
//
// The geoip stuff actually returns different geocodes for different parts of
// cities. This approach rolls up each city to the last geocoded location
// within that city, so it's not perfect, but for now it'll do.
function cacheCityGeocode(elasticSearch, log) {
  var index = 'api-umbrella';

  var id = log.request_ip_country + '-' + log.request_ip_region + '-' + log.request_ip_city;
  id = crypto.createHash('sha256').update(id).digest('hex');

  var record = {
    country: log.request_ip_country,
    region: log.request_ip_region,
    city: log.request_ip_city,
    location: log.request_ip_location,
    updated_at: moment().format(),
  };

  elasticSearch.index(index, 'city', record, id)
    .on('error', function(error) {
      logger.error('Index city error: ' + error);
    })
    .exec();
}

module.exports = function(elasticSearch, log) {
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

  if(log.request_ip_city && log.request_ip_location) {
    cacheCityGeocode(elasticSearch, log);
  }

  var urlParts = url.parse(log.request_url, true);

  if(log.request_url.indexOf('api_key') !== -1) {
    delete urlParts.search;
    delete urlParts.query.api_key;
    log.request_url = url.format(urlParts);
  }

  log.request_scheme = urlParts.protocol.replace(/:$/, '');
  log.request_host = urlParts.hostname;
  log.request_path = urlParts.pathname;
  log.request_path_hierarchy = urlParts.pathname.replace(/\.\w+$/, '');
  log.request_query = urlParts.query;

  if(log.request_user_agent) {
    var agent = uaParser.lookup(log.request_user_agent);
    log.request_user_agent_type = agent.type;
    log.request_user_agent_family = agent.uaFamily;

    if(!log.request_user_agent_family || log.request_user_agent_family === 'unknown') {
      var matches = log.request_user_agent.match(/^([^/\s]+)/);
      if(matches && matches[1] !== 'Mozilla') {
        log.request_user_agent_family = matches[1];
      }
    }

    if(!log.request_user_agent_type || log.request_user_agent_type === 'unknown') {
      log.request_user_agent_type = null;
    }

    if(!log.request_user_agent_family || log.request_user_agent_family === 'unknown') {
      log.request_user_agent_family = null;
    }
  }

  return log;
};
