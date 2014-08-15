'use strict';

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    async = require('async'),
    clc = require('cli-color'),
    events = require('events'),
    forever = require('forever-monitor'),
    fs = require('fs'),
    fsExtra = require('fs-extra'),
    glob = require('glob'),
    handlebars = require('handlebars'),
    http = require('http'),
    mkdirp = require('mkdirp'),
    net = require('net'),
    os = require('os'),
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

    var runDir = path.join(os.tmpdir(), 'api-umbrella');
    mkdirp.sync(runDir);

    apiUmbrellaConfig.loader({
      defaults: {
        run_dir: runDir,
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

    process.on('SIGINT', function() {
      this.stop(function() {
        process.exit(0);
      });
    }.bind(this));

    async.series([
      this.prepare.bind(this),
      this.writeTemplates.bind(this),
      this.startSupervisor.bind(this),
      this.waitForProcesses.bind(this),
      this.waitForConnections.bind(this),
    ], this.finishStart.bind(this));
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

    if(this.supervisordProcess && this.supervisordProcess.running) {
      this.supervisordProcess.stop();
    } else {
      this.finishStop();
    }
  },

  prepare: function(callback) {
    mkdirp.sync(this.config.get('mongodb.embedded_server_config.dbpath'));
    callback();
  },

  writeTemplates: function(callback) {
    var templateConfig = _.extend({}, this.config.getAll(), {
      api_umbrella_config_args: '--config ' + this.configLoader.runtimeFile,
      gatekeeper_hosts: _.times(this.config.get('gatekeeper.workers'), function(n) { return '127.0.0.1:' + (50000 + n); }),
      test_env: (this.config.get('app_env') == 'test'),
    });

    glob(this.config.get('config_dir') + '/**/*.hbs', function(error, templatePaths) {
      // Exclude the api_backends template, since we don't have the necessary
      // API backend information yet. This template gets managed by the
      // config_reloader worker process after things are started.
      templatePaths = _.without(templatePaths, path.join(this.config.get('config_dir'), 'nginx/api_backends.conf.hbs'));

      async.each(templatePaths, function(templatePath, eachCallback) {
        var templateContent = fs.readFileSync(templatePath);
        var template = handlebars.compile(templateContent.toString());
        var contents = template(templateConfig);

        var configPath = templatePath.replace(/\.hbs$/, '');
        fs.writeFile(configPath, contents, eachCallback);
      }, callback);
    }.bind(this));
  },

  startSupervisor: function(callback) {
    this.supervisordProcess = new (forever.Monitor)(['supervisord', '-c', 'config/supervisord.conf', '--nodaemon'], {
      max: 1,
      silent: true,
      logFile: path.resolve(__dirname, '../log/supervisor/supervisord_forever.log'),
      outFile: path.resolve(__dirname, '../log/supervisor/supervisord_forever.log'),
      errFile: path.resolve(__dirname, '../log/supervisor/supervisord_forever.log'),
      append: true,
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

    this.supervisordProcess.on('exit', this.finishStop.bind(this));

    this.supervisordProcess.start();
  },

  waitForProcesses: function(callback) {
    var client = supervisord.connect('http://localhost:9009');
    var connected = false;
    var attemptDelay = 100;
    async.until(function() {
      return connected;
    }, function(untilCallback) {
      client.getAllProcessInfo(function(error, result) {
        if(result && _.isEqual(_.uniq(_.pluck(result, 'statename')), ['RUNNING'])) {
          connected = true;
          untilCallback();
        } else {
          setTimeout(untilCallback, attemptDelay);
        }
      });
    }, callback);

    setTimeout(function() {
      if(!connected) {
        callback('Failed to start processes');
      }
    }.bind(this), 15000);
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

    var allConnected = false;
    var successfulConnections = [];

    async.each(listeners, function(listener, eachCallback) {
      var parsed = url.parse(listener);

      // Wait until we're able to establish a connection before moving on.
      var connected = false;
      var attemptDelay = 100;
      async.until(function() {
        return connected;
      }, function(untilCallback) {
        switch(parsed.protocol) {
          case 'http:':
            http.get(parsed.href, function(res) {
              if(res.statusCode === 200) {
                connected = true;
                successfulConnections.push(listener);
                untilCallback();
              } else {
                setTimeout(untilCallback, attemptDelay);
              }
            }).on('error', function() {
              setTimeout(untilCallback, attemptDelay);
            });
            break;
          case 'tcp:':
            net.connect({
              host: parsed.hostname,
              port: parsed.port,
            }).on('connect', function() {
              connected = true;
              successfulConnections.push(listener);
              untilCallback();
            }).on('error', function() {
              setTimeout(untilCallback, attemptDelay);
            });
            break;
          case 'unix:':
            net.connect({
              path: parsed.path,
            }).on('connect', function() {
              connected = true;
              successfulConnections.push(listener);
              untilCallback();
            }).on('error', function() {
              setTimeout(untilCallback, 100);
            });
            break;
        }
      }, eachCallback);
    }, function() {
      allConnected = true;
      callback();
    });

    setTimeout(function() {
      if(!allConnected) {
        callback('Unable to establish connections: ' + _.difference(listeners, successfulConnections).join(', '));
      }
    }.bind(this), 60000);
  },

  finishStart: function(error) {
    if(error) {
      console.info(' [' + clc.red('FAIL') + ']\n');
      console.error(error);
      if(this.supervisordProcess) {
        console.error('  See ' + this.supervisordProcess.logFile + ' for more details');
      }

      this.stop(function() {
        process.exit(1);
      });
    } else {
      clearInterval(this.startWaitLog);
      console.info(' [  ' + clc.green('OK') + '  ]');
      this.emit('ready');
    }
  },

  finishStop: function() {
    if(this.configLoader) {
      this.configLoader.close();
    }

    if(this.stopWaitLog) {
      clearInterval(this.stopWaitLog);
    }

    console.info(' [  ' + clc.green('OK') + '  ]');

    if(this.stopCallback) {
      this.stopCallback();
    }
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
