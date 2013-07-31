'use strict';

var _ = require('underscore'),
    utils = require('connect').utils,
    i18n = require('i18n');

module.exports = function apiKeyValidator(proxy) {
  var middleware = new ApiKeyValidator(proxy);

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  }
}

var ApiKeyValidator = function() {
  this.initialize.apply(this, arguments);
}

_.extend(ApiKeyValidator.prototype, {
  initialize: function(proxy) {
    this.proxy = proxy;
    this.users = this.proxy.mongo.collection('api_users');
    this.apiKeyMethods = this.proxy.config.get('proxy:api_key_methods');
  },

  handleRequest: function(request, response, next) {
    new ApiKeyValidatorRequest(this, request, response, next);
  },
});

var ApiKeyValidatorRequest = function() {
  this.initialize.apply(this, arguments);
}

_.extend(ApiKeyValidatorRequest.prototype, {
  initialize: function(validator, request, response, next) {
    this.validator = validator;
    this.proxy = validator.proxy;
    this.request = request;
    this.response = response;
    this.next = next;

    var apiKey = this.resolveApiKey();
    if(apiKey) {
      request.apiUmbrellaGatekeeper = {}
      request.apiUmbrellaGatekeeper.apiKey = apiKey;

      this.validator.users.findOne({
        api_key: request.apiUmbrellaGatekeeper.apiKey,
      }, this.handleUser.bind(this))
    } else {
      this.response.statusCode = 403;
      this.response.end(i18n.__('api_key_none', this.proxy.config.get('account_signup_uri')));
    }
  },

  resolveApiKey: function() {
    var apiKey;
    for(var i = 0, len = this.validator.apiKeyMethods.length; i < len; i++) {
      switch(this.validator.apiKeyMethods[i]) {
        case 'header':
          apiKey = this.request.headers['x-api-key'];
          break;
        case 'get_param':
          apiKey = this.request.query.api_key;
          break;
        case 'basic_auth_username':
          var authorization = this.request.headers.authorization;
          if(authorization) {
            var parts = authorization.split(' ');
            var scheme = parts[0];
            if(scheme == 'Basic') {
              var credentials = new Buffer(parts[1], 'base64').toString().split(':');
              apiKey = credentials[0];
            }
          }

          break;
      }

      if(apiKey) {
        break;
      }
    }

    return apiKey;
  },

  handleUser: function(error, user) {
    if(user) {
      if(!user.disabled_at) {
        this.request.apiUmbrellaGatekeeper.user = user;
        this.next();
      } else {
        this.response.statusCode = 403;
        this.response.end(i18n.__('api_key_disabled', this.proxy.config.get('contact_uri')));
      }
    } else {
      this.response.statusCode = 403;
      this.response.end(i18n.__('api_key_invalid', this.proxy.config.get('account_signup_uri')));
    }
  },
});
