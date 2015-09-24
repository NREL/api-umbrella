'use strict';

var crypto = require('crypto'),
    mongoose = global.mongoose || require('mongoose');

var schema = new mongoose.Schema({
  _id: mongoose.Schema.Types.Mixed,
  username: {
    type: String,
    index: { unique: true },
  },
  superuser: Boolean,
  authentication_token: String,
}, { collection: 'admins' });

schema.pre('validate', function generateApiKey(next) {
  if(!this.authentication_token) {
    // Create a random api key consisting of only A-Za-z0-9.
    this.authentication_token = crypto
      .randomBytes(64)
      .toString('base64')
      .replace(/[+\/=]/g, '')
      .slice(0, 40);
  }

  next();
});

module.exports = mongoose.model('Admin', schema);
