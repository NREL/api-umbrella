var path = require('path'),
    fs = require('fs'),
    Log = require('log');

var logDir = process.env.NODE_LOG_DIR || path.join(process.cwd(), 'log');
var environment = process.env.NODE_ENV || 'development';
var logLevel = process.env.NODE_LOG_LEVEL || 'info';
var logPath = path.join(logDir, environment + '.log');

var logger = new Log(logLevel, fs.createWriteStream(logPath, { flags: 'a' }));

module.exports = logger;
