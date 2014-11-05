'use strict';

require('./support/env');

var request = require('request'),
    Factory = require('factory-lady'),
    mongoose = require('mongoose');

global.request = request;
global.Factory = Factory;
global.mongoose = mongoose;

require('./support/delete_beanstalk');
require('./support/start_processes');

require('./support/chai');
require('./support/database_setup');
require('./support/factories');
require('./support/example_backend_app');
require('./support/keepalive_test_backend_app');

global.shared = {};

require('./support/helper_functions');
require('./support/config_reloader_shared_examples');

// Make sure this require stays at the bottom, so stopping the api-umbrella
// processes is the last callback to be performed (so other callbacks have an
// opportunity to gracefully close connections).
require('./support/stop_processes');
