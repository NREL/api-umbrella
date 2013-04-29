var _ = require('underscore'),
    async = require('async'),
    cluster = require('cluster'),
    haproxyLogListener = require('./haproxy_log_listener'),
    logProcessor = require('./log_processor'),
    nconf = require('nconf'),
    path = require('path'),
    proxy = require('./proxy');

exports.start = function(configOverrides, readyCallback) {
  var gatekeeper = new Gatekeeper(configOverrides, readyCallback);
  gatekeeper.start();
  return gatekeeper;
}

exports.startNonForked = function(configOverrides, readyCallback) {
  var gatekeeper = new Gatekeeper(configOverrides, readyCallback);
  gatekeeper.startNonForked();
  return gatekeeper;
}

var Gatekeeper = function() {
  this.initialize.apply(this, arguments);
}

_.extend(Gatekeeper.prototype, {
  initialize: function(configOverrides, readyCallback) {
    this.initConfig(configOverrides);
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
    process.title = 'api_umbrella_gatekeeper: ' + process.env.GATEKEEPER_WORKER_TYPE + ' worker';

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
    var numWorkers = parseInt(this.config.get('proxy:workers'));
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

  initConfig: function(configOverrides) {
    this.config = nconf;

    this.config.overrides(configOverrides);

    var configDir = process.env['NODE_CONFIG_DIR'] || process.cwd() + '/config';
    var env = process.env['NODE_ENV'] || 'development';
    this.config.file('environment', path.join(configDir, env + '.json'));

    this.config.file('defaults', path.resolve(__dirname, '../config/defaults' + '.json'));
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
