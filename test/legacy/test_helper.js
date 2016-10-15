'use strict';

// As a very first step, blow away the default test directory, so we have a
// fresh test directory, clean logs, etc. on every run.
var fs = require('fs'),
    mkdirp = require('mkdirp'),
    path = require('path'),
    rimraf = require('rimraf');
rimraf.sync('/tmp/api-umbrella-test');
mkdirp.sync('/tmp/api-umbrella-test/var/log');

if(!/^v0\.10\./.test(process.version)) {
  console.error('Legacy test suite must be run with nodejs v0.10 (current version: ' + process.version + ')');
  return process.exit(1);
}

global.API_UMBRELLA_SRC_ROOT = path.resolve(__dirname, '../../');
if(!fs.existsSync(path.join(global.API_UMBRELLA_SRC_ROOT, 'src/api-umbrella'))) {
  console.error('The calculated root directory does not appear correct: ' + global.API_UMBRELLA_SRC_ROOT);
  return process.exit(1);
}

require('./support/env');

var mongoose = require('mongoose');
global.mongoose = mongoose;

require('./support/start_processes');

require('./support/chai');
require('./support/database_setup');
require('./support/factories');
require('./support/keepalive_test_backend_app');

global.shared = {};
require('./support/helper_functions');
require('./support/server_shared_examples');

// Make sure this require stays at the bottom, so stopping the api-umbrella
// processes is the last callback to be performed (so other callbacks have an
// opportunity to gracefully close connections).
require('./support/stop_processes');
