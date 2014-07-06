'use strict';

require('./support/env');

var request = require('request'),
    Factory = require('factory-lady'),
    mongoose = require('mongoose');

global.request = request;
global.Factory = Factory;
global.mongoose = mongoose;

require('./support/processes');

require('./support/chai');
require('./support/database_setup');
require('./support/factories');
require('./support/example_backend_app');
require('./support/keepalive_test_backend_app');

global.shared = {};

require('./support/helper_functions');
