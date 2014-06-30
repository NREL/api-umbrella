'use strict';

var ApiUserSchema = require('./models/api_user_schema');

module.exports = {
  // Expose models externally so it can be shared with the router project for
  // tests.
  models: function(mongoose) {
    mongoose = mongoose || require('mongoose');

    return {
      ApiUser: mongoose.model('ApiUser', ApiUserSchema),
    };
  },
};
