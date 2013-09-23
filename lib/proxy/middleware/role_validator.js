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
    var requiredRoles = request.apiUmbrellaGatekeeper.settings.required_roles;

    var authenticated = true;
    if(requiredRoles && requiredRoles.length > 0) {
      authenticated = false;

      var userRoles = request.apiUmbrellaGatekeeper.user.roles;
      if(userRoles && userRoles.length > 0) {
        if(userRoles.indexOf('admin') !== -1) {
          authenticated = true;
        } else {
          for(var i = 0, len = requiredRoles.length; i < len; i++) {
            if(userRoles.indexOf(requiredRoles[i]) !== -1) {
              authenticated = true;
            }
          }
        }
      }
    }

    if(authenticated) {
      next();
    } else {
      response.statusCode = 403;

      var contactUri = config.get('contactUri');
      var host = request.headers.host;
      if(host.indexOf('whitehouse.gov') !== -1) {
        contactUri = 'https://petitions.whitehouse.gov';
      }
      response.end(i18n.__('api_key_unauthorized', contactUri));
    }
  }
});

module.exports = function roleValidator(proxy) {
  var middleware = new RoleValidator(proxy);

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};
