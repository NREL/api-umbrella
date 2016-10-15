'use strict';

var mongoose = global.mongoose || require('mongoose');

module.exports = mongoose.model('AdminPermission', new mongoose.Schema({
  _id: String,
  name: String,
  display_order: Number,
  created_at: Date,
  updated_at: Date,
}, { collection: 'admin_permissions', minimize: false }));
