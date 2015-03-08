'use strict';

var _ = require('lodash'),
    async = require('async'),
    beanstalkConnect = require('../beanstalk_connect'),
    config = require('api-umbrella-config').global(),
    dgram = require('dgram'),
    events = require('events'),
    fs = require('fs'),
    logger = require('../logger'),
    redis = require('redis'),
    simpleflake = require('simpleflake'),
    syslogParser = require('glossy').Parse,
    util = require('util');

var Worker = function() {
  this.initialize.apply(this, arguments);
};

module.exports.Worker = Worker;

util.inherits(Worker, events.EventEmitter);
_.extend(Worker.prototype, {
  initialize: function() {
    async.parallel([
      this.connectRedis.bind(this),
      this.connectBeanstalk.bind(this),
    ], this.startServer.bind(this));
  },

  connectRedis: function(asyncReadyCallback) {
    var connected = false;
    this.redis = redis.createClient(config.get('redis.port'), config.get('redis.host'));

    this.redis.on('error', function(error) {
      logger.error({ err: error }, 'redis error');
      if(!connected) {
        asyncReadyCallback(error);
      }
    });

    this.redis.on('ready', function() {
      connected = true;
      asyncReadyCallback(null);
    });
  },

  connectBeanstalk: function(asyncReadyCallback) {
    beanstalkConnect(function(error, client) {
      if(!error) {
        this.beanstalk = client;
      }

      asyncReadyCallback(error);
    }.bind(this));
  },

  startServer: function(error) {
    if(error) {
      logger.error(error);
      process.exit(1);
      return false;
    }

    this.server = dgram.createSocket('udp4');
    this.server.on('message', function(rawMessage) {
      this.handleSyslogMessage(rawMessage);
    }.bind(this));
    this.server.bind(config.get('router.log_listener.port'));

    this.emit('ready');
  },

  handleSyslogMessage: function(rawMessage) {
    var log = syslogParser.parse(rawMessage.toString());

    // Strip the program name portion of the syslog message to just get the
    // message body.
    var message = log.message.replace(/^\w+:\s*/, '');

    // The nginx log data is manually constructed JSON. It escapes quotes and
    // backslashes as hexadecimal escaped characters, so we manually need to
    // deal with it so it parses as JSON.
    message = message.replace(/\\x22/g, '\\"');
    message = message.replace(/\\x5C/g, '\\\\');

    // JSON.parse will bomb with the hexidecimal escaped characters that the
    // nginx logs use (since these aren't valid according to JSON:
    // http://stackoverflow.com/a/17961409/222487). This step replaces these
    // hexidecimal sequences with their string equivalent. This approach seems
    // a little ridiculous, but I can't really find another way to handle these
    // character sequences.
    //
    // The basic approach is that a url containing "✓" will get logged as
    // "\xE2\x9C\x93". This regex matches the entire sequence of hex-encoded
    // characters (since they have to be matched together, since "\xE2" just by
    // itself is something else). The regex does not match literal backslashes
    // like "\\xE2".  Once matched, we then strip the "\x" prefixes and then
    // pipe it to Node's Buffer class, where we can convert from "E29C93" back
    // into "✓". Now that the string is actually in UTF-8 (and no unsupported
    // hex escape sequences), we can pass that to JSON.parse.
    message = message.replace(/([^\\]|^)((\\x[a-fA-F0-9]{2})+)/g, function(match, p1, p2) {
      var hex = p2.replace(/\\x/g, '');
      return p1 + (new Buffer(hex, 'hex')).toString();
    });

    try {
      log = JSON.parse(message);
    } catch(error) {
      logger.error({ err: error, message: message }, 'JSON parse error for log message');
      return false;
    }

    // Workaround for url.parse replacing backslashes with forward slashes:
    // https://github.com/joyent/node/pull/8459 This is fixed in Node 0.12, but
    // since we're on Node 0.10, sidestep the issue by replacing backslashes
    // with their URL-encoded version (which url.parse won't flip).
    if(log.req_uri) {
      log.req_uri = log.req_uri.replace(/\\/g, '%5C');
    }

    // Strip values that are just the string '-'. This is used in nginx logs
    // to represent empty values, but we don't want to actually log this dash
    // character.
    log = _.mapValues(log, function(value) {
      if(value === '-') {
        value = undefined;
      }

      if(value && !isNaN(value)) {
        value = value * 1;
      }

      return value;
    });

    var data = JSON.stringify(log);
    this.push(log.id, log.source, data);
  },

  push: function(id, source, data) {
    if(!id) {
      id = simpleflake().toString('base58');
      logger.error({ temporaryId: id }, 'Missing unique request ID for logging. This should not occur. Make sure the "X-Api-Umbrella-Request-ID" HTTP header is present. Generated temporary ID.');
    }

    this.redis.hset('log:' + id, source, data, function(error) {
      if(error) {
        logger.error({ err: error, id: id, source: source, data: data }, 'Failed to set redis log data');
      }

      if(source === 'initial_router') {
        // Delay running by 1 second to allow out of order logs from the
        // different sources (api_backend_router and gatekeeper) a chance to
        // come in. Inside the log_processor task we will attempt further
        // delays if not all the log data is present, but this is just a small
        // delay to try to cover most situations.
        var delay = 1;
        var priority = 0;
        var ttr = 10;
        this.beanstalk.put(priority, delay, ttr, id, function(error) {
          if(error) {
            logger.error({ err: error, id: id, source: source, data: data }, 'Failed to queue log for processing');
          }
        });
      }
    }.bind(this));
  },

  close: function(callback) {
    if(this.beanstalk) {
      this.beanstalk.exit();
    }

    if(this.redis) {
      this.redis.quit();
    }

    if(this.server) {
      this.server.close();
    }

    if(this.socketPath && fs.existsSync(this.socketPath)) {
      fs.unlinkSync(this.socketPath);
    }

    if(callback) {
      callback(null);
    }
  },
});
