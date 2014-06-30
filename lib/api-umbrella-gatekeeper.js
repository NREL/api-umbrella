'use strict';

module.exports = {
  // Expose models externally so it can be shared with the router project for
  // tests.
  models: function(mongoose) {
    mongoose = mongoose || require('mongoose');

    var apiUserSchema = require('./models/api_user_schema');

    return {
      ApiUser: mongoose.model('ApiUser', apiUserSchema(mongoose)),
    };
  },
};
