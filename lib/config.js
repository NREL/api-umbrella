'use strict';

var _ = require('underscore'),
    atomic = new (require('atomic-write').Context)(),
    clone = require('clone'),
    dot = require('dot-component'),
    events = require('events'),
    extend = require('object-extend'),
    fs = require('fs'),
    lockFile = require('lockfile'),
    logger = require('./logger'),
    path = require('path'),
    util = require('util'),
    yaml = require('js-yaml');

var Config = function() {
  this.initialize.apply(this, arguments);
};

util.inherits(Config, events.EventEmitter);
_.extend(Config.prototype, {
  values: {},
  originalValues: {},
  runtimeValues: {},

  initialize: function() {
    this.moduleDefaultsPath = path.resolve(__dirname, '../config/default.yml');

    this.configDir = process.env.NODE_CONFIG_DIR || path.join(process.cwd(), 'config');
    this.appDefaultsPath = path.join(this.configDir, 'default.yml');

    this.environment = process.env.NODE_ENV || 'development';
    this.appEnvironmentPath = path.join(this.configDir, this.environment + '.yml');

    this.runtimePath = path.join(this.configDir, 'runtime.yml');
    this.runtimeLockPath = path.join(this.configDir, 'runtime.yml.lock');

    this.read();
    this.watchRuntime();
  },

  read: function() {
    this.readStaticFiles();
    this.readRuntimeFile();
    this.combineValues();
  },

  readStaticFiles: function() {
    var paths = [this.moduleDefaultsPath, this.appDefaultsPath, this.appEnvironmentPath];
    for(var i = 0; i < paths.length; i++) {
      var values = this.readYamlFile(paths[i]);
      extend(this.originalValues, values);
    }
  },

  readRuntimeFile: function() {
    this.runtimeValues = this.readYamlFile(this.runtimePath);
  },

  readYamlFile: function(path) {
    var values = {};

    if(fs.existsSync(path)) {
      var data = fs.readFileSync(path);
      values = yaml.safeLoad(data.toString());
    }

    return values;
  },

  combineValues: function() {
    this.values = clone(this.originalValues);
    extend(this.values, this.runtimeValues);

    logger.info('Reading new config (PID ' + process.pid + ')...');
    this.emit('reload');
  },

  get: function(key) {
    return dot.get(this.values.apiUmbrella, key);
  },

  reset: function(options) {
    this.values = clone(this.originalValues);
    if(!options || !options.quiet) {
      this.emit('reload');
    }
  },

  updateRuntime: function(values, options) {
    extend(this.runtimeValues, values);
    extend(this.values, values);
    if(!options || !options.quiet) {
      this.emit('reload');
    }
  },

  saveRuntime: function(callback) {
    lockFile.lock(this.runtimeLockPath, {}, function() {
      var data = yaml.safeDump(this.runtimeValues || {});
      atomic.writeFile(this.runtimePath, data, function(error) {
        if(callback) {
          callback(error);
        }
      });

    }.bind(this));
  },

  watchRuntime: function() {
    fs.watch(this.runtimePath, function(event) {
      // Only trigger on the change event, not the rename events fired by the
      // atomic-file writing in saveRuntime.
      if(event === 'change') {
        this.readRuntimeFile();
        this.combineValues();
      }
    }.bind(this));
  },
});

if(!global.API_UMBRELLA_CONFIG) {
  var config = new Config();

  // Set the global 'geodatadir' variable geoip-lite optionally reads from.
  var geoipDataDir = config.geoipDataDir;
  if(geoipDataDir) {
    global.geodatadir = geoipDataDir;
  }

  global.API_UMBRELLA_CONFIG = config;
}

module.exports = global.API_UMBRELLA_CONFIG;
