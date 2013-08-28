'use strict';

var _ = require('underscore'),
    clone = require('clone'),
    dot = require('dot-component'),
    fs = require('fs'),
    extend = require('object-extend'),
    lockFile = require('lockfile'),
    path = require('path'),
    yaml = require('js-yaml');

var Config = function() {
  this.initialize.apply(this, arguments);
};

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
    //this.watchRuntime();
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
  },

  get: function(key) {
    return dot.get(this.values.apiUmbrella, key);
  },

  reset: function() {
    this.values = clone(this.originalValues);
  },

  updateRuntime: function(values) {
    extend(this.runtimeValues, values);
    extend(this.values, values);
  },

  saveRuntime: function(callback) {
    lockFile.lock(this.runtimeLockPath, {}, function() {
      var data = yaml.safeDump(this.runtimeValues);
      fs.writeFile(this.runtimePath, data, function(error) {
        if(callback) {
          callback(error);
        }
      });
    }.bind(this));
  },

  watchRuntime: function() {
    fs.watch(this.runtimePath, function() {
      this.readRuntimeFile();
      this.combineValues();
    });
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
