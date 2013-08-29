'use strict';

var _ = require('underscore'),
    config = require('../../config'),
    i18n = require('i18n');

var RoleValidator = function() {
  this.initialize.apply(this, arguments);
};

_.extend(RoleValidator.prototype, {
  initialize: function() {
  },

  handleRequest: function(request, response, next) {
    var restrictedApis = config.get('proxy.restrictedApis');
    var requiredRoles = [];
    if(restrictedApis) {
      for(var i = 0, len = restrictedApis.length; i < len; i++) {
        var api = restrictedApis[i];
        var regex = new RegExp(api.pathRegex);
        if(regex.test(request.url)) {
          requiredRoles.push(api.role);
        }
      }
    }

    var authenticated = true;
    if(requiredRoles.length > 0) {
      authenticated = false;

      var userRoles = request.apiUmbrellaGatekeeper.user.roles;
      if(userRoles && userRoles.indexOf('admin') === -1) {
        var missingRoles = _.difference(requiredRoles, userRoles);
        if(missingRoles.length === 0) {
          authenticated = true;
        }
      }
    }

    if(authenticated) {
      next();
    } else {
      response.statusCode = 403;
      response.end(i18n.__('api_key_unauthorized', config.get('contactUri')));
    }
  }
});

module.exports = function roleValidator(proxy) {
  var middleware = new RoleValidator(proxy);

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};
