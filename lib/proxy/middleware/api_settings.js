'use strict';

var _ = require('lodash'),
    cloneDeep = require('clone'),
    config = require('../../config'),
    mergeOverwriteArrays = require('object-extend');

var ApiSettings = function() {
  this.initialize.apply(this, arguments);
};

_.extend(ApiSettings.prototype, {
  initialize: function() {
  },

  handleRequest: function(request, response, next) {
    var api = request.apiUmbrellaGatekeeper.matchedApi;

    // Fetch the default settings and merge those with the base API settings.
    var settings = cloneDeep(config.get('apiSettings'));
    mergeOverwriteArrays(settings, api.settings);

    // See if there's any settings for a matching sub-url.
    if(api.sub_settings) {
      for(var i = 0, len = api.sub_settings.length; i < len; i++) {
        var subSettings = api.sub_settings[i];
        if(subSettings.http_method === 'any' || subSettings.http_method === request.method) {
          if(subSettings.regex.test(request.url)) {
            // Merge the matching sub-settings in.
            mergeOverwriteArrays(settings, subSettings.settings);

            // We've deep-merged the root settings and the sub-settings
            // together, but cached attributes are a special case, where we
            // want to perform a non-deep merge.
            //
            // This is due to the caching of "append_query_string" into
            // "append_query_object". This cached value is an object
            // representation of those query parameters, but since the original
            // value is a string, a deep merge of the object is incorrect. We
            // need to replace the values wholesale.
            //
            // This should be revisited if we start to cache other variables,
            // since this behavior may not be correct in all instances.
            settings.cache = _.extend({}, api.settings.cache, subSettings.settings.cache);

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
