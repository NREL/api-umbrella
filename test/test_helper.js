'use strict';

require('./support/env');

var request = require('request'),
    Factory = require('factory-lady'),
    mongoose = require('mongoose'),
    gatekeeper = require('../lib/gatekeeper');

global.request = request;
global.Factory = Factory;
global.gatekeeper = gatekeeper;
global.mongoose = mongoose;

require('./support/chai');
require('./support/config');
require('./support/database_setup');
require('./support/factories');
require('./support/example_backend_app');

global.shared = {};
require('./support/distributed_rate_limits_sync_shared_examples');
require('./support/server_shared_examples');
