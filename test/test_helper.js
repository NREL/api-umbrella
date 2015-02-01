'use strict';

require('./support/env');

var fs = require('fs'),
    path = require('path');

if(!fs.existsSync(path.resolve(__dirname, './log'))) {
  fs.mkdirSync(path.resolve(__dirname, './log'));
}

if(!fs.existsSync(path.resolve(__dirname, './tmp'))) {
  fs.mkdirSync(path.resolve(__dirname, './tmp'));
}

require('./support/chai');
require('./support/database_setup');
require('./support/start_processes');
require('./support/factories');
require('./support/example_backend_app');

global.shared = {};
require('./support/distributed_rate_limits_sync_shared_examples');
require('./support/server_shared_examples');

// Make sure this require stays at the bottom, so stopping the api-umbrella
// processes is the last callback to be performed (so other callbacks have an
// opportunity to gracefully close connections).
require('./support/stop_processes');
