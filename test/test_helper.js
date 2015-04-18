'use strict';

// As a very first step, blow away the default test directory, so we have a
// fresh test directory, clean logs, etc. on every run.
var mkdirp = require('mkdirp'),
    rimraf = require('rimraf');
rimraf.sync('/tmp/api-umbrella-test');
mkdirp.sync('/tmp/api-umbrella-test/var/log');

require('./support/env');

var mongoose = require('mongoose');
global.mongoose = mongoose;

require('./support/delete_beanstalk');
require('./support/start_processes');

require('./support/chai');
require('./support/database_setup');
require('./support/example_backend_app');
require('./support/factories');
require('./support/keepalive_test_backend_app');

global.shared = {};
require('./support/config_reloader_shared_examples');
require('./support/distributed_rate_limits_sync_shared_examples');
require('./support/helper_functions');
require('./support/server_shared_examples');

// Make sure this require stays at the bottom, so stopping the api-umbrella
// processes is the last callback to be performed (so other callbacks have an
// opportunity to gracefully close connections).
require('./support/stop_processes');
