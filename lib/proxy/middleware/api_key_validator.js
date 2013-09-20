'use strict';

var _ = require('underscore'),
    config = require('../../config'),
    i18n = require('i18n');

var ApiKeyValidatorRequest = function() {
  this.initialize.apply(this, arguments);
};

_.extend(ApiKeyValidatorRequest.prototype, {
  initialize: function(validator, request, response, next) {
    this.validator = validator;
    this.request = request;
    this.response = response;
    this.next = next;

    var apiKey = this.resolveApiKey();
    if(apiKey) {
      request.apiUmbrellaGatekeeper.apiKey = apiKey;

      this.validator.users.findOne({
        api_key: request.apiUmbrellaGatekeeper.apiKey,
      }, this.handleUser.bind(this, request));
    } else {
      if(request.apiUmbrellaGatekeeper.settings && request.apiUmbrellaGatekeeper.settings.disable_api_key) {
        next();
      } else {
        this.response.statusCode = 403;

        var accountSignupUri = config.get('accountSignupUri');
        var host = request.headers.host;
        if(host.indexOf('whitehouse.gov') !== -1) {
          accountSignupUri = 'https://petitions.whitehouse.gov'
        }
        this.response.end(i18n.__('api_key_none', accountSignupUri));
      }
    }
  },

  resolveApiKey: function() {
    var apiKey;
    for(var i = 0, len = this.validator.apiKeyMethods.length; i < len; i++) {
      switch(this.validator.apiKeyMethods[i]) {
      case 'header':
        apiKey = this.request.headers['x-api-key'];
        break;
      case 'getParam':
        apiKey = this.request.query.api_key;
        break;
      case 'basicAuthUsername':
        var authorization = this.request.headers.authorization;
        if(authorization) {
          var parts = authorization.split(' ');
          var scheme = parts[0];
          if(scheme === 'Basic') {
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

  handleUser: function(request, error, user) {
    if(user) {
      if(!user.disabled_at) {
        this.request.apiUmbrellaGatekeeper.user = user;
        this.next();
      } else {
        this.response.statusCode = 403;

        var contactUri = config.get('contactUri');
        var host = request.headers.host;
        if(host.indexOf('whitehouse.gov') !== -1) {
          contactUri = 'https://petitions.whitehouse.gov'
        }
        this.response.end(i18n.__('api_key_disabled', contactUri));
      }
    } else {
      this.response.statusCode = 403;

      var accountSignupUri = config.get('accountSignupUri');
      var host = request.headers.host;
      if(host.indexOf('whitehouse.gov') !== -1) {
        accountSignupUri = 'https://petitions.whitehouse.gov'
      }
      this.response.end(i18n.__('api_key_invalid', accountSignupUri));
    }
  },
});

var ApiKeyValidator = function() {
  this.initialize.apply(this, arguments);
};

_.extend(ApiKeyValidator.prototype, {
  initialize: function(proxy) {
    this.users = proxy.mongo.collection('api_users');
    this.apiKeyMethods = config.get('proxy.apiKeyMethods');
  },

  handleRequest: function(request, response, next) {
    new ApiKeyValidatorRequest(this, request, response, next);
  },
});

module.exports = function apiKeyValidator(proxy) {
  var middleware = new ApiKeyValidator(proxy);

  return function(request, response, next) {
    middleware.handleRequest(request, response, next);
  };
};
