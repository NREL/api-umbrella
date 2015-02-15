'use strict';

var mongoose = global.mongoose || require('mongoose');

module.exports = mongoose.model('Admin', new mongoose.Schema({
  _id: mongoose.Schema.Types.Mixed,
  username: {
    type: String,
    index: { unique: true },
  },
  superuser: Boolean,
}, { collection: 'admins' }));
