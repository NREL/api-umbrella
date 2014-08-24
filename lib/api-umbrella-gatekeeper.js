'use strict';

module.exports = {
  // Expose models externally so it can be shared with the router project for
  // tests.
  models: function(mongoose) {
    mongoose = mongoose || require('mongoose');

    var apiSchema = require('./models/api_schema');
    var apiUserSchema = require('./models/api_user_schema');

    return {
      Api: mongoose.model('Api', apiSchema(mongoose)),
      ApiUser: mongoose.model('ApiUser', apiUserSchema(mongoose)),
    };
  },

  logger: require('./logger'),
  GatekeeperLogger: require('./gatekeeper/logger').Logger,
};
