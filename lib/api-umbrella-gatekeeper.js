'use strict';

var _ = require('lodash');

module.exports = {
  cachedModels: {},

  // Expose models externally so it can be shared with the router project for
  // tests.
  models: function(mongoose) {
    // Allow the mongoose object to be passed in, so the router project can
    // define models on it's own version of mongoose (which may differ from the
    // gatekeeper's version).
    mongoose = mongoose || require('mongoose');

    // Ensure that the models are only defined once per instance of mongoose
    // (otherwise mongoose freaks out). Not sure this is really the best way to
    // be doing all this, but it seems to do the trick..
    mongoose._uniqueObjectId = mongoose._uniqueObjectId || _.uniqueId();
    if(!this.cachedModels[mongoose._uniqueObjectId]) {
      var apiSchema = require('./models/api_schema');
      var apiUserSchema = require('./models/api_user_schema');

      this.cachedModels[mongoose._uniqueObjectId] = {
        Api: mongoose.model('Api', apiSchema(mongoose)),
        ApiUser: mongoose.model('ApiUser', apiUserSchema(mongoose)),
      };
    }

    return this.cachedModels[mongoose._uniqueObjectId];
  },

  wrappedLogger: function() {
    var logger = require('./logger');
    return logger;
  },
};
