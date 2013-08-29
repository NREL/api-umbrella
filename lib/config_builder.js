'use strict';

var _ = require('underscore'),
    async = require('async'),
    config = require('./config'),
    fs = require('fs'),
    handlebars = require('handlebars'),
    events = require('events'),
    path = require('path'),
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
    var collection = this.mongo.collection('apis');
    var cursor = collection.find().sort({ sort_order: 1 });
    cursor.toArray(this.handleFetchApis.bind(this));
  },

  handleFetchApis: function(error, apis) {
    this.apis = apis;
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
    var frontendHosts = _.uniq(_.pluck(this.apis, 'frontend_host'));

    this.apis.forEach(function(api) {
      if(api.balance_algorithm === 'least_conn' || api.balance_algorithm === 'ip_hash') {
        api.defaultBalance = false;
      } else {
        api.defaultBalance = true;
      }
    });

    var newContent = this.nginxTemplate({
      hosts: frontendHosts,
      apis: this.apis,
    });

    var nginxPath = '/tmp/blah.txt';

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
    var configApis = this.apis.map(function(api) {
      var configApi = _.pick(api, 'frontend_host', 'backend_host');
      configApi.id = api._id.toHexString();

      configApi.url_matches = api.url_matches.map(function(urlMatch) {
        return _.omit(urlMatch, '_id');
      });

      return configApi;
    });

    config.reset();

    if(configApis && configApis.length > 0) {
      config.updateRuntime({ apiUmbrella: { apis: configApis } });
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
