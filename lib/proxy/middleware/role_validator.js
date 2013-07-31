'use strict';

var _ = require('underscore'),
    i18n = require('i18n');

module.exports = function roleValidator(proxy) {
  var middleware = new RoleValidator(proxy);

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};

var RoleValidator = function() {
  this.initialize.apply(this, arguments);
};

_.extend(RoleValidator.prototype, {
  initialize: function(proxy) {
    this.proxy = proxy;
    this.restrictedApis = this.proxy.config.get('proxy:restricted_apis');
  },

  handleRequest: function(request, response, next) {
    var requiredRoles = [];
    if(this.restrictedApis) {
      for(var i = 0, len = this.restrictedApis.length; i < len; i++) {
        var api = this.restrictedApis[i];
        var regex = new RegExp(api.path_regex);
        if(regex.test(request.url)) {
          requiredRoles.push(api.role);
        }
      }
    }

    var authenticated = true;
    if(requiredRoles.length > 0) {
      authenticated = false;

      var userRoles = request.apiUmbrellaGatekeeper.user.roles;
      if(userRoles && userRoles.indexOf('admin') == -1) {
        var missingRoles = _.difference(requiredRoles, userRoles);
        if(missingRoles.length == 0) {
          authenticated = true;
        }
      }
    }

    if(authenticated) {
      next();
    } else {
      response.statusCode = 403;
      response.end(i18n.__('api_key_unauthorized', this.proxy.config.get('contact_uri')));
    }
  }
});
