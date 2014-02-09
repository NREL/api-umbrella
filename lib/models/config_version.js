'use strict';

var mongoose = global.mongoose || require('mongoose');

module.exports = mongoose.model('ConfigVersion', new mongoose.Schema({
  version: {
    type: Date,
    unique: true,
  },
  config: mongoose.Schema.Types.Mixed,
}, { collection: 'config_versions' }));
