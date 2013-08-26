'use strict';

var _ = require('underscore'),
    async = require('async'),
    cluster = require('cluster'),
    config = require('./config'),
    routerLogListener = require('./router_log_listener'),
    logProcessor = require('./log_processor'),
    proxy = require('./proxy');

var Gatekeeper = function() {
  this.initialize.apply(this, arguments);
};

_.extend(Gatekeeper.prototype, {
  initialize: function(readyCallback) {
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
    case 'router_log_listener':
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
    this.proxyWorker = new proxy.Worker();
    if(callback) {
      this.proxyWorker.on('ready', callback);
    }

    return this.proxyWorker;
  },

  startHaproxyLogListener: function(callback) {
    this.routerLogListenerWorker = new routerLogListener.Worker();
    if(callback) {
      this.routerLogListenerWorker.on('ready', callback);
    }

    return this.routerLogListenerWorker;
  },

  startLogProcessor: function(callback) {
    this.logProcessorWorker = new logProcessor.Worker();
    if(callback) {
      this.logProcessorWorker.on('ready', callback);
    }

    return this.logProcessorWorker;
  },

  forkProxyWorkers: function(startupCallback) {
    var numWorkers = parseInt(config.get('proxy.workers'), 10);
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
    var numWorkers = parseInt(config.get('routerLogListener.workers'), 10);
    async.times(numWorkers, function(index, forkCallback) {
      var worker = cluster.fork({ GATEKEEPER_WORKER_TYPE: 'router_log_listener' });
      worker.on('exit', this.handleHaproxyLogWorkerExit.bind(this));
      worker.on('listening', function() {
        forkCallback(null);
      });
    }.bind(this), function(error) {
      startupCallback(error);
    });
  },

  forkLogProcessorWorkers: function(startupCallback) {
    var numWorkers = parseInt(config.get('logProcessor.workers'), 10);
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

  handleProxyWorkerExit: function(code) {
    console.warn('proxy worker ' + process.pid + ' died ('+code+'). restarting...');
    new proxy.Worker();
  },

  handleHaproxyLogWorkerExit: function(code) {
    console.warn('router log listener worker ' + process.pid + ' died ('+code+'). restarting...');
    new routerLogListener.Worker();
  },

  handleLogWorkerExit: function(code) {
    console.warn('log processor worker ' + process.pid + ' died ('+code+'). restarting...');
    new logProcessor.Worker();
  },

  closeNonForked: function(callback) {
    var closeFunctions = [];
    if(this.proxyWorker) {
      closeFunctions.push(this.proxyWorker.close.bind(this.proxyWorker));
    }

    if(this.routerLogListenerWorker) {
      closeFunctions.push(this.routerLogListenerWorker.close.bind(this.routerLogListenerWorker));
    }

    async.parallel(closeFunctions, callback);
  },
});

exports.start = function(readyCallback) {
  var gatekeeper = new Gatekeeper(readyCallback);
  gatekeeper.start();
  return gatekeeper;
};

exports.startNonForked = function(readyCallback) {
  var gatekeeper = new Gatekeeper(readyCallback);
  gatekeeper.startNonForked();
  return gatekeeper;
};

