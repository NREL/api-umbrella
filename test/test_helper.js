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
require('./support/database_setup');
require('./support/factories');
require('./support/example_backend_app');
require('./support/server_shared_examples');
