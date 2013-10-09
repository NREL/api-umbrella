'use strict';

var _ = require('underscore'),
    clone = require('clone'),
    config = require('../../config');

var ApiSettings = function() {
  this.initialize.apply(this, arguments);
};

_.extend(ApiSettings.prototype, {
  initialize: function() {
  },

  handleRequest: function(request, response, next) {
    var api = request.apiUmbrellaGatekeeper.matchedApi;

    var settings = clone(config.get('apiSettings'));
    _.extend(settings, api.settings);
    if(api.sub_settings) {
      for(var i = 0, len = api.sub_settings.length; i < len; i++) {
        var subSettings = api.sub_settings[i];
        if(subSettings.http_method === 'any' || subSettings.http_method === request.method) {
          if(subSettings.regex.test(request.url)) {
            _.extend(settings, subSettings.settings);
            break;
          }
        }
      }
    }

    request.apiUmbrellaGatekeeper.settings = settings;

    next();
  },
});

module.exports = function apiSettings() {
  var middleware = new ApiSettings();

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};
