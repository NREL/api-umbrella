'use strict';

require('../test_helper');

var ConfigVersion = mongoose.model('config_versions', {
  version: Date,
  config: mongoose.Schema.Types.Mixed,
});

function generateVersion(callback) {
  callback(new Date());
}

Factory.define('config_version', ConfigVersion, {
  version: generateVersion,
  config: {},
});
