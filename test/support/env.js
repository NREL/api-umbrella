'use strict';

var path = require('path');

process.env.NODE_ENV = 'test';
process.env.NODE_LOG_DIR = path.resolve(__dirname, '../log');
