'use strict';

require('../test_helper');

var config = require('api-umbrella-config'),
    path = require('path');

config.setFiles([
  path.resolve(__dirname, '../../config/default.yml'),
  path.resolve(__dirname, '../config/test.yml'),
]);
