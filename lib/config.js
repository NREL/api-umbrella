'use strict';

var _ = require('lodash'),
    atomic = new (require('atomic-write').Context)(),
    cloneDeep = require('clone'),
    dot = require('dot-component'),
    events = require('events'),
    fs = require('fs'),
    lockFile = require('lockfile'),
    logger = require('./logger'),
    mergeOverwriteArrays = require('object-extend'),
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

    this.runtimeConfigDir = process.env.NODE_RUNTIME_CONFIG_DIR || this.configDir;
    this.runtimePath = path.join(this.runtimeConfigDir, 'runtime.yml');
    this.runtimeLockPath = path.join(this.runtimeConfigDir, 'runtime.yml.lock');

    this.logDir = process.env.NODE_LOG_DIR || path.join(process.cwd(), 'log');

    // Make sure the file exists, or the file watcher will fail.
    var fd = fs.openSync(this.runtimePath, 'a');
    fs.closeSync(fd);

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
      mergeOverwriteArrays(this.originalValues, values);
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
    this.values = cloneDeep(this.originalValues);
    mergeOverwriteArrays(this.values, this.runtimeValues);

    logger.info('Reading new config (PID ' + process.pid + ')...');
    logger.debug(JSON.stringify(this.values, null, 2));
    this.emit('reload');
  },

  get: function(key) {
    return dot.get(this.values.apiUmbrella, key);
  },

  getOriginal: function(key) {
    return dot.get(this.originalValues.apiUmbrella, key);
  },

  reset: function(options) {
    this.values = cloneDeep(this.originalValues);
    this.runtimeValues = {};
    if(!options || !options.quiet) {
      this.emit('reload');
    }
  },

  updateRuntime: function(values, options) {
    mergeOverwriteArrays(this.runtimeValues, values);
    mergeOverwriteArrays(this.values, values);
    if(!options || !options.quiet) {
      this.emit('reload');
    }
  },

  saveRuntime: function(callback) {
    lockFile.lock(this.runtimeLockPath, {}, function() {
      var data = yaml.safeDump(this.runtimeValues || {});
      logger.info('Writing new config (PID ' + process.pid + ')...');
      logger.debug(data);
      atomic.writeFile(this.runtimePath, data, function(error) {
        if(callback) {
          callback(error);
        }
      });

    }.bind(this));
  },

  watchRuntime: function() {
    var dir = path.dirname(this.runtimePath);
    var filename = path.basename(this.runtimePath);

    // Watch the directory, not the file for runtime.yml changes. File-based
    // watching breaks down when files get moved around, which the atomic-file
    // writing in saveRuntime does. Watching the directory fixes this.
    fs.watch(dir, function(event, watchedFile) {
      if(filename === watchedFile) {
        logger.info('Config file change detected (PID ' + process.pid + ')... ');
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
