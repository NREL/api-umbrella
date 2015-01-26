'use strict';

var fs = require('fs'),
    path = require('path'),
    yaml = require('js-yaml');

fs.writeFileSync('/tmp/api-umbrella-test.yml', yaml.safeDump({
  router: {
    dir: path.resolve(__dirname, '../../'),
  },
}));

process.env.NODE_ENV = 'test';
process.env.API_UMBRELLA_LOG_LEVEL = 'debug';
process.env.API_UMBRELLA_LOG_PATH = path.resolve(__dirname, '../log/test.log');

// redis-convoy uses the config module and requires a bit more setup when in
// the test environment (the defaults don't get loaded if NODE_ENV=test.
process.env.NODE_CONFIG_DIR = path.resolve(__dirname, '../config');
process.env.NODE_RUNTIME_CONFIG_DIR = process.env.NODE_CONFIG_DIR;
