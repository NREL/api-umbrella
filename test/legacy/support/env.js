'use strict';

var fs = require('fs'),
    yaml = require('js-yaml');

fs.writeFileSync('/tmp/api-umbrella-test.yml', yaml.safeDump({
  router: {
    dir: global.API_UMBRELLA_SRC_ROOT,
  },
}));

process.env.NODE_ENV = 'test';
process.env.API_UMBRELLA_LOG_LEVEL = 'debug';
global.CACHING_SERVER = 'trafficserver';
