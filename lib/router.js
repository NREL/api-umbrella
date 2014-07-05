'use strict';

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    async = require('async'),
    clc = require('cli-color'),
    events = require('events'),
    forever = require('forever-monitor'),
    fs = require('fs'),
    handlebars = require('handlebars'),
    http = require('http'),
    mkdirp = require('mkdirp'),
    net = require('net'),
    path = require('path'),
    supervisord = require('supervisord'),
    spawn = require('child_process').spawn,
    url = require('url'),
    util = require('util');

var Router = function() {
  this.initialize.apply(this, arguments);
};

util.inherits(Router, events.EventEmitter);
_.extend(Router.prototype, {
  initialize: function(options) {
    process.stdout.write('Starting api-umbrella...');
    this.startWaitLog = setInterval(function() {
      process.stdout.write('.');
    }, 500);

    apiUmbrellaConfig.loader({
      defaults: {
        run_dir: path.resolve(__dirname, '../run'),
        log_dir: path.resolve(__dirname, '../log'),
        config_dir: path.resolve(__dirname, '../config'),
        gatekeeper_dir: path.resolve(__dirname, '../gatekeeper'),
      },
      paths: [
        path.resolve(__dirname, '../config/default.yml'),
      ].concat(options.config),
    }, this.handleConfigReady.bind(this));
  },

  handleConfigReady: function(error, configLoader) {
    this.configLoader = configLoader;
    this.config = apiUmbrellaConfig.load(this.configLoader.runtimeFile);

    process.on('SIGINT', this.stop.bind(this));

    async.series([
      this.prepare.bind(this),
      this.writeTemplates.bind(this),
      this.startSupervisor.bind(this),
      this.waitForProcesses.bind(this),
      this.waitForConnections.bind(this),
      this.emitReady.bind(this),
    ]);
  },

  start: function() {
  },

  stop: function(callback) {
    this.stopCallback = callback;

    process.stdout.write('\nStopping api-umbrella...');
    this.stopWaitLog = setInterval(function() {
      process.stdout.write('.');
    }, 500);


    if(this.configLoader) {
      this.configLoader.close();
    }

    if(this.supervisordProcess) {
      this.supervisordProcess.stop();
    }
  },

  prepare: function(callback) {
    mkdirp.sync(this.config.get('mongodb.embedded_server_config.dbpath'));
    callback();
  },

  writeTemplates: function(callback) {
    var templates = [
      'supervisord.conf.hbs',
      'nginx/frontend_proxy_header_defaults.conf.hbs',
      'nginx/frontend_defaults.conf.hbs',
      'nginx/gatekeeper.conf.hbs',
      'nginx/router.conf.hbs',
      'nginx/web.conf.hbs',
      'redis.conf.hbs',
      'mongod.conf.hbs',
      'elasticsearch/elasticsearch-env.sh.hbs',
      'elasticsearch/elasticsearch.yml.hbs',
      'varnish.vcl.hbs',
    ];

    var templateConfig = _.extend({}, this.config.getAll(), {
      api_umbrella_config_args: '--config ' + this.configLoader.runtimeFile,
      gatekeeper_hosts: _.times(this.config.get('gatekeeper.workers'), function(n) { return '127.0.0.1:' + (50000 + n); }),
    });

    async.each(templates, function(filename, eachCallback) {
      var templatePath = path.resolve(__dirname, '../config/' + filename);
      var templateContent = fs.readFileSync(templatePath);
      var template = handlebars.compile(templateContent.toString());
      var contents = template(templateConfig);

      var configPath = templatePath.replace(/\.hbs$/, '');
      fs.writeFile(configPath, contents, eachCallback);
    }, callback);
  },

  startSupervisor: function(callback) {
    this.supervisordProcess = new (forever.Monitor)(['supervisord', '-c', 'config/supervisord.conf', '--nodaemon'], {
      max: 1,
      silent: true,
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

    this.supervisordProcess.on('error', function() {
      console.info('error: ', arguments);
    });

    this.supervisordProcess.on('start', function() {
      callback();
    });

    this.supervisordProcess.on('restart', function() {
      console.info('restart: ');
    });

    this.supervisordProcess.on('exit', function(code) {
      this.configLoader.close();
      if(this.stopWaitLog) {
        clearInterval(this.stopWaitLog);
      }

      console.info(' [  ' + clc.green('OK') + '  ]');

      if(this.stopCallback) {
        this.stopCallback();
      }
    }.bind(this));

    this.supervisordProcess.start();
  },

  waitForProcesses: function(callback) {
    var client = supervisord.connect('http://localhost:9009');
    var connected = false;
    async.until(function() {
      return connected;
    }, function(untilCallback) {
      client.getAllProcessInfo(function(error, result) {
        if(result && _.isEqual(_.uniq(_.pluck(result, 'statename')), ['RUNNING'])) {
          connected = true;
          untilCallback();
        } else {
          setTimeout(untilCallback, 100);
        }
      });
    }, callback);
  },

  waitForConnections: function(callback) {
    var listeners = [
      'http://127.0.0.1:' + this.config.get('elasticsearch.embedded_server_config.http_port'),
      'tcp://127.0.0.1:' + this.config.get('redis.port'),
      'tcp://127.0.0.1:' + this.config.get('varnish.port'),
      'tcp://127.0.0.1:' + this.config.get('http_port'),
      'tcp://127.0.0.1:' + this.config.get('web.port'),
      this.config.get('web.puma.bind'),
    ];

    async.each(listeners, function(listener, eachCallback) {
      var parsed = url.parse(listener);

      // Wait until we're able to establish a connection before moving on.
      var connected = false;
      async.until(function() {
        return connected;
      }, function(untilCallback) {
        switch(parsed.protocol) {
          case 'http:':
            http.get(parsed.href, function(res) {
              if(res.statusCode === 200) {
                connected = true;
                untilCallback();
              } else {
                setTimeout(untilCallback, 100);
              }
            }).on('error', function() {
              setTimeout(untilCallback, 100);
            });
            break;
          case 'tcp:':
            net.connect({
              host: parsed.hostname,
              port: parsed.port,
            }).on('connect', function() {
              connected = true;
              untilCallback();
            }).on('error', function() {
              setTimeout(untilCallback, 100);
            });
            break;
          case 'unix:':
            net.connect({
              path: parsed.path,
            }).on('connect', function() {
              connected = true;
              untilCallback();
            }).on('error', function() {
              setTimeout(untilCallback, 100);
            });
            break;
        }
      }, eachCallback);
    }, callback);
  },

  emitReady: function() {
    clearInterval(this.startWaitLog);
    console.info(' [  ' + clc.green('OK') + '  ]');
    this.emit('ready');
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
