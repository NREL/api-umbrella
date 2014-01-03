'use strict';

require('../test_helper');
require('../../lib/models/config_version');

function generateVersion(callback) {
  callback(new Date());
}

Factory.define('config_version', mongoose.testConnection.model('ConfigVersion'), {
  version: generateVersion,
  config: {},
});
