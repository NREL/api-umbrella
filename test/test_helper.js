'use strict';

require('./support/env');

var gatekeeper = require('../lib/gatekeeper');

global.gatekeeper = gatekeeper;

require('./support/chai');
require('./support/database_setup');
require('./support/factories');
require('./support/example_backend_app');

global.shared = {};
require('./support/distributed_rate_limits_sync_shared_examples');
require('./support/server_shared_examples');
