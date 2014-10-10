var fs = require('fs'),
    Log = require('log');

var logLevel = process.env.API_UMBRELLA_LOG_LEVEL || 'info';
var stream = process.stdout;
if(process.env.API_UMBRELLA_LOG_PATH) {
  stream = fs.createWriteStream(process.env.API_UMBRELLA_LOG_PATH, {
    flags: 'a'
  });
}

var logger = new Log(logLevel, stream);
module.exports = logger;
