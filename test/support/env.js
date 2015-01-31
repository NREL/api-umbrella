'use strict';

var path = require('path');

process.env.NODE_ENV = 'test';
process.env.API_UMBRELLA_LOG_LEVEL = 'debug';
process.env.API_UMBRELLA_LOG_PATH = path.resolve(__dirname, '../log/test.log');
