var Log = require('log');

var logLevel = process.env.NODE_LOG_LEVEL || 'info';
var logger = new Log(logLevel);
module.exports = logger;
