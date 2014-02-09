'use strict';

var path = require('path');

process.env.PATH = '/opt/api-umbrella/bin:/opt/api-umbrella/embedded/bin:/opt/nginx/sbin:' + path.resolve(__dirname, '../../gatekeeper/bin') + ':' + process.env.PATH;
process.env.NODE_ENV = 'test';
process.env.NODE_CONFIG_DIR = path.resolve(__dirname, '../config');
process.env.NODE_RUNTIME_CONFIG_DIR = path.resolve(__dirname, '../config');
process.env.NODE_LOG_DIR = path.resolve(__dirname, '../log');
