'use strict';

require('./support/env');

var request = require('request'),
    Factory = require('factory-lady'),
    mongoose = require('mongoose');

global.request = request;
global.Factory = Factory;
global.mongoose = mongoose;

require('./support/chai');
require('./support/database_setup');
require('./support/factories');

require('./support/processes');

global.shared = {};
