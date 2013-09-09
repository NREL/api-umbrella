'use strict';

var _ = require('underscore'),
    async = require('async'),
    clone = require('clone'),
    config = require('./config'),
    fs = require('fs'),
    handlebars = require('handlebars'),
    events = require('events'),
    path = require('path'),
    traverse = require('traverse'),
    util = require('util');

var ConfigBuilder = function() {
  this.initialize.apply(this, arguments);
};

util.inherits(ConfigBuilder, events.EventEmitter);
_.extend(ConfigBuilder.prototype, {
  initialize: function(mongo, readyCallback) {
    this.mongo = mongo;

    var templatePath = path.resolve(__dirname, '../templates/nginx.hbs');
    var templateContent = fs.readFileSync(templatePath);
    this.nginxTemplate = handlebars.compile(templateContent.toString());

    this.once('reloaded', readyCallback);
    this.reload();
  },

  reload: function() {
    var collection = this.mongo.collection('config_versions');
    var cursor = collection.find().sort({ version: -1 }).limit(1);
    cursor.toArray(this.handleFetchConfigVersion.bind(this));
  },

  handleFetchConfigVersion: function(error, configVersions) {
    this.lastConfig = configVersions[0];

    if(this.lastConfig) {
      this.apis = this.lastConfig.config.apis;
    }

    if(!this.apis) {
      this.apis = [];
    }

    this.writeConfigs();
  },

  writeConfigs: function() {
    // Write nginx config's first.
    async.series([
      this.writeNginxConfig.bind(this),
      this.writeGatekeeperConfig.bind(this),
    ], this.handleWriteConfigs.bind(this));
  },

  writeNginxConfig: function(writeCallback) {
    var apis = _.reject(clone(this.apis), function(api) {
      return (!api.servers || api.servers.length === 0);
    });

    var frontendHosts = _.reject(_.uniq(_.pluck(apis, 'frontend_host')), function(host) {
      return !host;
    });

    apis.forEach(function(api) {
      if(api.balance_algorithm === 'least_conn' || api.balance_algorithm === 'ip_hash') {
        api.defaultBalance = false;
      } else {
        api.defaultBalance = true;
      }
    });

    var newContent = this.nginxTemplate({
      logDir: path.resolve(config.configDir, '../log'),
      hosts: frontendHosts,
      apis: apis,
    });

    var nginxPath = path.join(config.configDir, 'gatekeeper_nginx.conf');

    var write = function() {
      fs.writeFile(nginxPath, newContent, function() {
        this.emit('nginx');
        writeCallback(null);
      }.bind(this));
    }.bind(this);

    fs.exists(nginxPath, function(exists) {
      if(exists) {
        fs.readFile(nginxPath, function(error, data) {
          var oldContent = data.toString();
          if(oldContent === newContent) {
            writeCallback(null);
          } else {
            write();
          }
        });
      } else {
        write();
      }
    });
  },

  writeGatekeeperConfig: function(writeCallback) {
    config.reset();

    if(this.lastConfig) {
      var values = clone(this.lastConfig.config);
      traverse(values).forEach(function(value) {
        if(value && value._bsontype && value._bsontype === 'ObjectID') {
          this.update(value.toHexString());
        }
      });

      values.version = this.lastConfig.version;

      config.updateRuntime({ apiUmbrella: values });
    }

    config.saveRuntime(function() {
      writeCallback(null);
    });
  },

  handleWriteConfigs: function() {
    this.emit('reloaded');
  },
});

module.exports.ConfigBuilder = ConfigBuilder;
