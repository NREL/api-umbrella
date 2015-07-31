'use strict';

var crypto = require('crypto');

module.exports = function(mongoose) {
  mongoose = mongoose || require('mongoose');

  var schema = new mongoose.Schema({
    _id: mongoose.Schema.Types.Mixed,
    api_key: {
      type: String,
      index: { unique: true },
    },
    created_at: Date,
    first_name: String,
    last_name: String,
    email: String,
    email_verified: Boolean,
    website: String,
    registration_source: String,
    throttle_by_ip: Boolean,
    disabled_at: Date,
    roles: [String],
    settings: mongoose.Schema.Types.Mixed,
  }, { collection: 'api_users' });

  schema.pre('validate', function generateApiKey(next) {
    if(!this.api_key) {
      // Create a random api key consisting of only A-Za-z0-9.
      this.api_key = crypto
        .randomBytes(64)
        .toString('base64')
        .replace(/[+\/=]/g, '')
        .slice(0, 40);
    }

    next();
  });

  return schema;
};
