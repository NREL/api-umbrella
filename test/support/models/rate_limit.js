'use strict';

var mongoose = global.mongoose || require('mongoose');

module.exports = mongoose.model('RateLimit', new mongoose.Schema({
  _id: String,
  count: Number,
  updated_at: {
    type: Date,
    index: true,
  },
  expire_at: {
    type: Date,
    expires: 0,
  },
}, { collection: 'rate_limits', minimize: false }));
