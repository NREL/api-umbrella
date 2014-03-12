'use strict';

var _ = require('lodash'),
    config = require('api-umbrella-config'),
    events = require('events'),
    fs = require('fs'),
    handlebars = require('handlebars'),
    mkdirp = require('mkdirp'),
    path = require('path'),
    spawn = require('child_process').spawn,
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

    var templates = [
      'supervisord.conf.hbs',
      'nginx/router.conf.hbs',
      'nginx/web.conf.hbs',
      'redis.conf.hbs',
      'mongod.conf.hbs',
      'elasticsearch/elasticsearch-env.sh.hbs',
      'elasticsearch/elasticsearch.yml.hbs',
    ];

    var templateConfig = _.extend({}, config.getAll(), {
      run_dir: path.resolve(__dirname, '../run'),
      log_dir: path.resolve(__dirname, '../log'),
      config_dir: path.resolve(__dirname, '../config'),
      api_umbrella_config_args: _.map(options.config, function(file) { return '--config ' + file; }).join(' '),
      gatekeeper_hosts: _.times(config.get('gatekeeper.workers'), function(n) { return '127.0.0.1:' + (50000 + n); }),
    });

    mkdirp.sync(config.get('mongodb.embedded_server_config.dbpath'));

    templates.forEach(function(filename) {
      var templatePath = path.resolve(__dirname, '../config/' + filename);
      var templateContent = fs.readFileSync(templatePath);
      var supervisorTemplate = handlebars.compile(templateContent.toString());
      var contents = supervisorTemplate(templateConfig);

      var configPath = templatePath.replace(/\.hbs$/, '');
      fs.writeFileSync(configPath, contents);
    });

    var supervisord = spawn('supervisord', ['-c', 'config/supervisord.conf', '-n']);

    supervisord.stdout.on('data', function (data) {
      console.log('stdout: ' + data);
    });

    supervisord.stderr.on('data', function (data) {
      console.log('stderr: ' + data);
    });

    supervisord.on('close', function (code) {
      console.log('child process exited with code ' + code);
    });
  },

  start: function() {
  },

  stop: function() {
  },
});

_.extend(exports, {
  run: function(options, callback) {
    var router = new Router(options);
    router.on('ready', router.start);
    return router;
  },

  start: function(options, callback) {
    var router = new Router(options);
    router.on('ready', router.run);
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
