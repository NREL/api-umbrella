'use strict';

require('./support/env');

var fs = require('fs'),
    gatekeeper = require('../lib/gatekeeper'),
    path = require('path');

if(!fs.existsSync(path.resolve(__dirname, './log'))) {
  fs.mkdirSync(path.resolve(__dirname, './log'));
}

if(!fs.existsSync(path.resolve(__dirname, './tmp'))) {
  fs.mkdirSync(path.resolve(__dirname, './tmp'));
}

global.gatekeeper = gatekeeper;

require('./support/chai');
require('./support/database_setup');
require('./support/factories');
require('./support/example_backend_app');

global.shared = {};
require('./support/distributed_rate_limits_sync_shared_examples');
require('./support/server_shared_examples');
