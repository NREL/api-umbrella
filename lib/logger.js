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

  // Use syslog levels, but don't use Winston's built-in levels, since those
  // are currently broken: https://github.com/flatiron/winston/issues/249
  // levels: winston.config.syslog.levels,
  levels: {
    debug: 0,
    info: 1,
    notice: 2,
    warning: 3,
    error: 4,
    crit: 5,
    alert: 6,
    emerg: 7
  },
});

module.exports = logger;
