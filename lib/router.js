'use strict';

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    async = require('async'),
    events = require('events'),
    fs = require('fs'),
    handlebars = require('handlebars'),
    mkdirp = require('mkdirp'),
    path = require('path'),
    supervisord = require('supervisord'),
    spawn = require('child_process').spawn,
    util = require('util');

var Router = function() {
  this.initialize.apply(this, arguments);
};

util.inherits(Router, events.EventEmitter);
_.extend(Router.prototype, {
  initialize: function(options) {
    apiUmbrellaConfig.loader({
      defaults: {
        run_dir: path.resolve(__dirname, '../run'),
        log_dir: path.resolve(__dirname, '../log'),
        config_dir: path.resolve(__dirname, '../config'),
        gatekeeper_dir: path.resolve(__dirname, '../gatekeeper'),
      },
      paths: [
        path.resolve(__dirname, '../config/default.yml'),
        //path.resolve(__dirname, '../gatekeeper/config/default.yml'),
      ].concat(options.config),
    }, this.handleConfigReady.bind(this));
  },

  handleConfigReady: function(error, configLoader) {
    this.configLoader = configLoader;

    var config = apiUmbrellaConfig.load(this.configLoader.runtimeFile);

    var templates = [
      'supervisord.conf.hbs',
      'nginx/router.conf.hbs',
      'nginx/web.conf.hbs',
      'redis.conf.hbs',
      'mongod.conf.hbs',
      'elasticsearch/elasticsearch-env.sh.hbs',
      'elasticsearch/elasticsearch.yml.hbs',
      'varnish.vcl.hbs',
    ];

    var templateConfig = _.extend({}, config.getAll(), {
      api_umbrella_config_args: '--config ' + this.configLoader.runtimeFile,
      gatekeeper_hosts: _.times(config.get('gatekeeper.workers'), function(n) { return '127.0.0.1:' + (50000 + n); }),
    });

    mkdirp.sync(config.get('mongodb.embedded_server_config.dbpath'));

    templates.forEach(function(filename) {
      var templatePath = path.resolve(__dirname, '../config/' + filename);
      var templateContent = fs.readFileSync(templatePath);
      var template = handlebars.compile(templateContent.toString());
      var contents = template(templateConfig);

      var configPath = templatePath.replace(/\.hbs$/, '');
      fs.writeFileSync(configPath, contents);
    });

    var supervisordProcess = spawn('supervisord', ['-c', 'config/supervisord.conf', '--nodaemon'], {
      env: {
        'PATH': [
          path.resolve(__dirname, '../bin'),
          path.resolve(__dirname, '../gatekeeper/bin'),
          '/opt/api-umbrella/embedded/elasticsearch/bin',
          '/opt/api-umbrella/embedded/sbin',
          '/opt/api-umbrella/embedded/bin',
          '/usr/local/sbin',
          '/usr/local/bin',
          '/usr/sbin',
          '/usr/bin',
          '/sbin',
          '/bin',
        ].join(':'),
        'API_UMBRELLA_CONFIG': this.configLoader.runtimeFile,
      }
    });

    supervisordProcess.stdout.on('data', function(data) {
      process.stdout.write(data);
    });

    supervisordProcess.stderr.on('data', function(data) {
      process.stderr.write(data);
    });

    supervisordProcess.on('close', function(code) {
      console.info('supervisord close: ', code);
    });

    var client = supervisord.connect('http://localhost:9009');
    var connected = false;
    async.until(function() {
      return connected;
    }, function(callback) {
      client.getAllProcessInfo(function(error, result) {
        console.info(_.uniq(_.pluck(result, 'statename')));
        if(result && _.isEqual(_.uniq(_.pluck(result, 'statename')), ['RUNNING'])) {
          connected = true;
          callback();
        } else {
          setTimeout(callback, 100);
        }
      });
    }, function() {
      this.emit('ready');
    }.bind(this));
  },

  start: function() {
  },

  stop: function() {
  },
});

_.extend(exports, {
  run: function(options, callback) {
    var router = new Router(options);
    if(callback) {
      router.once('ready', callback);
    }

    return router;
  },

  start: function(options, callback) {
    var router = new Router(options);
    if(callback) {
      router.once('ready', callback);
    }

    return router;
  },

  stop: function(options, callback) {
    var router = new Router(options);
    if(callback) {
      router.once('ready', callback);
    }

    return router;
  },
});
