'use strict';

var _ = require('lodash'),
    path = require('path');

_.extend(exports, {
  supervisordConfigPath: path.resolve(__dirname, '../config/supervisord.conf'),
  env: {
    'PATH': [
      path.resolve(__dirname, '../bin'),
      path.resolve(__dirname, '../gatekeeper/bin'),
      '/opt/api-umbrella/embedded/elasticsearch/bin',
      '/opt/api-umbrella/embedded/sbin',
      '/opt/api-umbrella/embedded/bin',
      '/usr/local/sbin',
      '/usr/local/bin',
      '/usr/sbin',
      '/usr/bin',
      '/sbin',
      '/bin',
    ].join(':'),
  },
});
