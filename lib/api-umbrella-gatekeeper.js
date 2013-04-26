var _ = require('underscore'),
    async = require('async'),
    cluster = require('cluster'),
    haproxyLogListener = require('./haproxy_log_listener'),
    logProcessor = require('./log_processor'),
    nconf = require('nconf'),
    proxy = require('./proxy');

exports.start = function(config, readyCallback) {
  var gatekeeper = new Gatekeeper(config, readyCallback);
  gatekeeper.start();
  return gatekeeper;
}

exports.startNonForked = function(config, readyCallback) {
  var gatekeeper = new Gatekeeper(config, readyCallback);
  gatekeeper.startNonForked();
  return gatekeeper;
}

var Gatekeeper = function() {
  this.initialize.apply(this, arguments);
}

_.extend(Gatekeeper.prototype, {
  initialize: function(config, readyCallback) {
    this.initConfig(config);
    this.readyCallback = readyCallback;
  },

  start: function() {
    if(cluster.isMaster) {
      this.startMaster();
    } else {
      this.startWorkers();
    }
  },

  startNonForked: function() {
    async.parallel([
      this.startProxy.bind(this),
      this.startHaproxyLogListener.bind(this),
      this.startLogProcessor.bind(this),
    ], this.handleStartFinish.bind(this));
  },

  startMaster: function() {
    async.parallel([
      this.forkProxyWorkers.bind(this),
      this.forkHaproxyLogListenerWorkers.bind(this),
      this.forkLogProcessorWorkers.bind(this),
    ], this.handleStartFinish.bind(this));
  },

  handleStartFinish: function(error) {
    if(error) {
      console.error(error);
      process.exit(1);
      return false;
    }

    if(this.readyCallback) {
      this.readyCallback(null);
    }
  },

  startWorkers: function() {
    process.title = 'api_umbrella_gatekeeper: ' + process.env.GATEKEEPER_WORKER_TYPE;

    switch(process.env.GATEKEEPER_WORKER_TYPE) {
      case 'proxy':
        this.startProxy();
        break;
      case 'haproxy_log_listener':
        this.startHaproxyLogListener();
        break;
      case 'log_processor':
        this.startLogProcessor();
        break;
      default:
        console.warn('Unexpected worker type: ' + process.env.GATEKEEPER_WORKER_TYPE);
        break;
    }
  },

  startProxy: function(callback) {
    this.proxyWorker = new proxy.Worker(this);
    if(callback) {
      this.proxyWorker.on('ready', callback);
    }

    return this.proxyWorker;
  },

  startHaproxyLogListener: function(callback) {
    this.haproxyLogListenerWorker = new haproxyLogListener.Worker(this);
    if(callback) {
      this.haproxyLogListenerWorker.on('ready', callback);
    }

    return this.haproxyLogListenerWorker;
  },

  startLogProcessor: function(callback) {
    this.logProcessorWorker = new logProcessor.Worker(this);
    if(callback) {
      this.logProcessorWorker.on('ready', callback);
    }

    return this.logProcessorWorker;
  },

  forkProxyWorkers: function(startupCallback) {
    var numWorkers = parseInt(this.config.get('proxy-workers'));
    async.times(numWorkers, function(index, forkCallback) {
      var worker = cluster.fork({ GATEKEEPER_WORKER_TYPE: 'proxy' });
      worker.on('exit', this.handleProxyWorkerExit.bind(this));
      worker.on('listening', function() {
        forkCallback(null);
      });
    }.bind(this), function(error) {
      startupCallback(error);
    });
  },

  forkHaproxyLogListenerWorkers: function(startupCallback) {
    var numWorkers = parseInt(this.config.get('haproxy_log_listener:workers'));
    async.times(numWorkers, function(index, forkCallback) {
      var worker = cluster.fork({ GATEKEEPER_WORKER_TYPE: 'haproxy_log_listener' });
      worker.on('exit', this.handleHaproxyLogWorkerExit.bind(this));
      worker.on('listening', function() {
        forkCallback(null);
      });
    }.bind(this), function(error) {
      startupCallback(error);
    });
  },

  forkLogProcessorWorkers: function(startupCallback) {
    var numWorkers = parseInt(this.config.get('log_processor:workers'));
    async.times(numWorkers, function(index, forkCallback) {
      var worker = cluster.fork({ GATEKEEPER_WORKER_TYPE: 'log_processor' });
      worker.on('exit', this.handleLogWorkerExit.bind(this));
      worker.on('online', function() {
        forkCallback(null);
      });
    }.bind(this), function(error) {
      startupCallback(error);
    });
  },

  handleProxyWorkerExit: function(code, signal) {
    console.warn('proxy worker ' + process.pid + ' died ('+code+'). restarting...');
    new proxy.Worker(this);
  },

  handleHaproxyLogWorkerExit: function(code, signal) {
    console.warn('haproxy log listener worker ' + process.pid + ' died ('+code+'). restarting...');
    new haproxyLogListener.Worker(this);
  },

  handleLogWorkerExit: function(code, signal) {
    console.warn('log processor worker ' + process.pid + ' died ('+code+'). restarting...');
    new logProcessor.Worker(this);
  },

  initConfig: function(config) {
    this.config = nconf;

    this.config.overrides(config);

    this.config.env();

    this.config.argv({
      'h': {
        alias: 'host',
        default: '0.0.0.0',
        describe: 'Hostname to bind to',
      },
      'p': {
        alias: 'port',
        default: '7890',
        describe: 'Port to lisen on',
      },
      'w': {
        alias: 'proxy-workers',
        default: '1',
        describe: 'number of workers to spawn',
      },
      't': {
        alias: 'target',
        default: '127.0.0.1:50100',
        describe: 'Backend server to proxy to',
      },
      'm': {
        alias: 'mongo',
        default: 'mongodb://127.0.0.1:27017/api_umbrella_development',
        describe: 'Mongo connection string',
      },
      'r': {
        alias: 'redis',
        default: '127.0.0.1:6379',
        describe: 'Redis connection string',
      },
      'e': {
        alias: 'environment',
        default: 'development',
        describe: 'Framework environment',
      },
      'c': {
        alias: 'config',
        default: 'config/api_umbrella_gatekeeper.json',
        describe: 'Framework environment',
      },
    });

    this.config.file(this.config.get('config'));

    this.config.defaults({
      account_signup_uri: 'http://example.com/',
      contact_uri: 'http://example.com/contact',
      api_key_methods: [
        'header',
        'get_param',
        'basic_auth_username',
      ],
      trusted_proxies: ['127.0.0.1'],
      rate_limits: [
        {
          duration: 1 * 1000, // 1 second
          accuracy: 500, // 500 milliseconds
          limit_by: 'ip',
          limit: 250000,
          distributed: false,
        }, {
          duration: 1 * 1000, // 1 second
          accuracy: 500, // 500 milliseconds
          limit_by: 'api_key',
          limit: 150000,
          distributed: false,
        }, {
          duration: 60 * 60 * 1000, // 1 hour
          accuracy: 1 * 60 * 1000, // 1 minute
          limit_by: 'api_key',
          limit: 10000000,
          distributed: true,
        }
      ],
      log_processor: {
        workers: 1,
      },
      haproxy_log_listener: {
        workers: 1,
        port: 5114,
      }
    });

    var redis = this.config.get('redis');
    var redisConnection = {};
    if(redis.charAt(0) == '/') {
      redisConnection.path = redis;
    } else {
      var parts = redis.split(':');
      redisConnection.host = parts[0];
      redisConnection.port = parts[1];
    }

    this.config.set('redis_connection', redisConnection);
  },

  closeNonForked: function(callback) {
    var closeFunctions = [];
    if(this.proxyWorker) {
      closeFunctions.push(this.proxyWorker.close.bind(this.proxyWorker));
    }

    if(this.haproxyLogListenerWorker) {
      closeFunctions.push(this.haproxyLogListenerWorker.close.bind(this.haproxyLogListenerWorker));
    }

    async.parallel(closeFunctions, callback);
  },
});
