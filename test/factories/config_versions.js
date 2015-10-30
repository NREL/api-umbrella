'use strict';

require('../test_helper');

var Factory = require('factory-lady'),
    mongoose = require('mongoose');

mongoose.model('RouterConfigVersion', new mongoose.Schema({
  version: {
    type: Date,
    unique: true,
  },
  config: mongoose.Schema.Types.Mixed,
}, { collection: 'config_versions', minimize: false }));

Factory.define('config_version', mongoose.testConnection.model('RouterConfigVersion'), {
  version: function(callback) {
    callback(new Date());
  },
});
