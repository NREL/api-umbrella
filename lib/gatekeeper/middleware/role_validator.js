'use strict';

var _ = require('lodash'),
    utils = require('../utils');

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
              break;
            }
          }
        }
      }
    }

    if(authenticated) {
      next();
    } else {
      utils.errorHandler(request, response, 'api_key_unauthorized');
    }
  }
});

module.exports = function roleValidator(proxy) {
  var middleware = new RoleValidator(proxy);

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};
