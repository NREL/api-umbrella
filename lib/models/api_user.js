'use strict';

var mongoose = require('mongoose');

module.exports = mongoose.model('ApiUser', new mongoose.Schema({
  _id: mongoose.Schema.Types.Mixed,
  api_key: {
    type: String,
    index: { unique: true },
  },
  first_name: String,
  last_name: String,
  email: String,
  website: String,
  registration_source: String,
  throttle_by_ip: Boolean,
  disabled_at: Date,
  roles: [String],
  settings: mongoose.Schema.Types.Mixed,
}, { collection: 'api_users' }));
