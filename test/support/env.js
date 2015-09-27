'use strict';

var config = require('./config'),
    fs = require('fs'),
    path = require('path'),
    yaml = require('js-yaml');

fs.writeFileSync('/tmp/api-umbrella-test.yml', yaml.safeDump({
  router: {
    dir: path.resolve(__dirname, '../../'),
  },
}));

process.env.NODE_ENV = 'test';
process.env.API_UMBRELLA_LOG_LEVEL = 'debug';
process.env.API_UMBRELLA_LOG_PATH = path.join(config.get('log_dir'), 'test.log');
global.CACHING_SERVER = 'trafficserver';
