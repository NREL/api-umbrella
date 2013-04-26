var _ = require('underscore'),
    dgram = require('dgram'),
    events = require('events'),
    redis = require('redis'),
    syslogParser = require('glossy').Parse,
    util = require('util');

var Worker = function() {
  this.initialize.apply(this, arguments);
}

module.exports.Worker = Worker;

util.inherits(Worker, events.EventEmitter);
_.extend(Worker.prototype, {
  initialize: function(gatekeeper) {
    this.config = gatekeeper.config;
    this.connectRedis(this.handleConnections.bind(this));
  },

  connectRedis: function(asyncReadyCallback) {
    this.redis = redis.createClient(this.config.get('redis_connection'));

    this.redis.on('error', function(error) {
      asyncReadyCallback(error);
    });

    this.redis.on('ready', function(error) {
      asyncReadyCallback(null);
    });
  },

  handleConnections: function(error, results) {
    if(error) {
      console.error(error);
      process.exit(1);
      return false;
    }

    this.proxyLogger = new ProxyLogger(this.redis);
    this.startServer();
    this.emit('ready');
  },

  startServer: function() {
    this.server = dgram.createSocket('udp4');
    this.server.on('message', this.handleMessage.bind(this));
    this.server.bind(this.config.get('haproxy_log_listener:port'));
  },

  handleMessage: function(rawMessage) {
    var log = syslogParser.parse(rawMessage);
    var parts = log.message.split(' ');
    var frontend = parts[2];

    var uid = null;
    switch(frontend) {
      case 'web_router':
        uid = parts[13];
        break;
      case 'api_router':
        if(parts[14]) {
          var capturedHeaders = parts[14].replace(/(^{|}$)/g, '').split('|');
          uid = capturedHeaders[0];
        }
        break;
      default:
        console.info('UNEXPECTED LOG: ', log.message);
        break;
    }

    if(!uid || !uid.match(/[0-9A-Z]{40}$/)) {
      console.info('UNEXPECTED UID: ', uid);
    } else {
      this.proxyLogger.push(uid, frontend, log.message);
    }
  },

  close: function(callback) {
    if(this.server) {
      this.server.close();
    }

    if(callback) {
      callback(null);
    }
  },
});
