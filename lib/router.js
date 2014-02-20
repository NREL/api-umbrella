'use strict';

var _ = require('lodash'),
    config = require('api-umbrella-config'),
    events = require('events'),
    fs = require('fs'),
    handlebars = require('handlebars'),
    path = require('path'),
    util = require('util');

var Router = function() {
  this.initialize.apply(this, arguments);
};

util.inherits(Router, events.EventEmitter);
_.extend(Router.prototype, {
  initialize: function(options) {
    config.setFiles([
      path.resolve(__dirname, '../config/default.yml'),
    ].concat(options.config));

    var templatePath = path.resolve(__dirname, '../config/supervisord.conf.hbs');
    var templateContent = fs.readFileSync(templatePath);
    var supervisorTemplate = handlebars.compile(templateContent.toString());
    var contents = supervisorTemplate({
      run_dir: path.resolve(__dirname, '../run'),
      log_dir: path.resolve(__dirname, '../log'),
      config_dir: path.resolve(__dirname, '../config'),
      varnish_port: config.get('varnish.port'),
      api_umbrella_config_args: _.map(options.config, function(file) { return '--config ' + file; }).join(' '),
    });

    var configPath = path.resolve(__dirname, '../config/supervisord.conf');
    fs.writeFileSync(configPath, contents);

    var templatePath = path.resolve(__dirname, '../config/nginx/router.conf.hbs');
    var templateContent = fs.readFileSync(templatePath);
    var supervisorTemplate = handlebars.compile(templateContent.toString());
    var contents = supervisorTemplate({
      http_port: config.get('http_port'),
      https_port: config.get('https_port'),
      log_dir: path.resolve(__dirname, '../log'),
      apis: config.get('apis'),
      nginx: config.get('nginx'),
      gatekeeper_hosts: _.times(config.get('gatekeeper.workers'), function(n) { return '127.0.0.1:' + (50000 + n); }),
    });

    var configPath = path.resolve(__dirname, '../config/nginx/router.conf');
    fs.writeFileSync(configPath, contents);
  },

  start: function() {
  },

  stop: function() {
  },
});

_.extend(exports, {
  start: function(options, callback) {
    var router = new Router(options);
    router.on('ready', router.start);
    return router;
  },

  stop: function(options, callback) {
    var router = new Router(options);
    if(callback) {
      router.on('ready', callback);
    }

    return router;
  },
});
