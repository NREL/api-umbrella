'use strict';

var path = require('path');

process.env.NODE_ENV = 'test';

// redis-convoy uses the config module and requires a bit more setup when in
// the test environment (the defaults don't get loaded if NODE_ENV=test.
process.env.NODE_CONFIG_DIR = path.resolve(__dirname, '../config');
process.env.NODE_RUNTIME_CONFIG_DIR = process.env.NODE_CONFIG_DIR;
