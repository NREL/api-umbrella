'use strict';

var _ = require('lodash'),
    config = require('api-umbrella-config').global(),
    csv = require('csv'),
    events = require('events'),
    fs = require('fs'),
    logger = require('api-umbrella-gatekeeper').logger,
    path = require('path'),
    GatekeeperLogger = require('api-umbrella-gatekeeper').GatekeeperLogger,
    redis = require('redis'),
    Tail = require('always-tail'),
    util = require('util');

var Worker = function() {
  this.initialize.apply(this, arguments);
};

module.exports.Worker = Worker;

util.inherits(Worker, events.EventEmitter);
_.extend(Worker.prototype, {
  initialize: function() {
    this.connectRedis(this.handleLogs.bind(this));
  },

  connectRedis: function(asyncReadyCallback) {
    this.redis = redis.createClient(config.get('redis'));

    this.redis.on('error', function(error) {
      asyncReadyCallback(error);
    });

    this.redis.on('ready', function() {
      asyncReadyCallback(null);
    });
  },

  handleLogs: function(error) {
    if(error) {
      logger.error(error);
      process.exit(1);
      return false;
    }

    this.gatekeeperLogger = new GatekeeperLogger(this.redis);

    this.logPath = path.resolve(process.cwd(), path.join(config.get('log_dir'), 'router.log'));

    // Make sure the file exists, or the Tail module will die.
    if(!fs.existsSync(this.logPath)) {
      var fd = fs.openSync(this.logPath, 'a');
      fs.closeSync(fd);
    }

    this.tailLog();
    this.emit('ready');
  },

  tailLog: function() {
    fs.stat(this.logPath, function(error, stats) {
      var start = 0;
      if(!error) {
        start = stats.size;
      }

      this.tail = new Tail(this.logPath, '\n', { start: start });
      this.tail.on('line', this.handleLogLine.bind(this));
      this.tail.watch();
    }.bind(this));
  },

  handleLogLine: function(line) {
    csv().from(line).to.array(function(rows) {
      var row = rows[0];

      var uid = row[0];
      var routerName = row[1];
      var log = {
        logged_at: parseFloat(row[3]),
        response_time: parseFloat(row[4]),
        backend_response_time: parseFloat(row[5]),
        request_size: parseInt(row[6], 10),
        response_size: parseInt(row[7], 10),
        response_status: parseInt(row[8], 10),
        request_ip: row[9],
        request_method: row[10],
        request_scheme: row[11],
        request_host: row[12],
        request_port: row[13],
        request_uri: row[14],
        request_user_agent: row[15],
        request_referer: row[16],
        request_api_key_header: row[17],
        request_basic_auth_username: row[18],
      };

      // Strip values that are just the string '-'. This is used in nginx logs
      // to represent empty values, but we don't want to actually log this dash
      // character.
      log = _.mapValues(log, function(value) {
        if(value === '-') {
          value = undefined;
        }

        return value;
      });

      var data = JSON.stringify(log);
      this.gatekeeperLogger.push(uid, routerName, data);
    }.bind(this));
  },

  close: function(callback) {
    if(this.redis) {
      this.redis.quit();
    }

    if(this.tail) {
      this.tail.unwatch();
    }

    if(callback) {
      callback(null);
    }
  },
});
