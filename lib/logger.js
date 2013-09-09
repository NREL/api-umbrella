var path = require('path'),
    winston = require('winston');

var logDir = process.env.NODE_LOG_DIR || path.join(process.cwd(), 'log');
var environment = process.env.NODE_ENV || 'development';

var logger = new (winston.Logger)({
  transports: [
    new (winston.transports.File)({
      filename: path.join(logDir, environment + '.log'),
      json: false,
    })
  ],
  levels: winston.config.syslog.levels,
});

module.exports = logger;
