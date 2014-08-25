'use strict';

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    async = require('async'),
    clc = require('cli-color'),
    events = require('events'),
    execFile = require('child_process').execFile,
    forever = require('forever-monitor'),
    fs = require('fs'),
    fsExtra = require('fs-extra'),
    glob = require('glob'),
    handlebars = require('handlebars'),
    http = require('http'),
    mkdirp = require('mkdirp'),
    mongoConnect = require('./mongo_connect'),
    mongoose = require('mongoose'),
    net = require('net'),
    os = require('os'),
    path = require('path'),
    processEnv = require('./process_env'),
    supervisord = require('supervisord'),
    spawn = require('child_process').spawn,
    url = require('url'),
    util = require('util'),
    uuid = require('node-uuid'),
    yaml = require('js-yaml');

var models = require('api-umbrella-gatekeeper').models(mongoose);

var ApiUser = models.ApiUser;

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

    process.on('SIGHUP', this.reload.bind(this));
    process.on('SIGINT', this.stop.bind(this, function() {
      process.exit(0);
    }));

    apiUmbrellaConfig.loader({
      defaults: {
        config_dir: path.resolve(__dirname, '../config'),
      },
      paths: [
        path.resolve(__dirname, '../config/default.yml'),
      ].concat(options.config),
    }, this.handleConfigReady.bind(this));
  },

  handleConfigReady: function(error, configLoader) {
    this.configLoader = configLoader;
    this.config = apiUmbrellaConfig.load(this.configLoader.runtimeFile);

    async.series([
      this.prepare.bind(this),
      this.internalConfigDefaults.bind(this),
      this.setupGlobalConfig.bind(this),
      this.writeTemplates.bind(this),
      this.startSupervisor.bind(this),
      this.waitForProcesses.bind(this),
      this.waitForConnections.bind(this),
      mongoConnect,
      this.seedDatabase.bind(this),
      this.writeStaticSiteEnv.bind(this),
    ], this.finishStart.bind(this));
  },

  reload: function() {
    var configPath = processEnv.supervisordConfigPath;
    var execOpts = {
      env: processEnv.env,
    };

    execFile('supervisorctl', ['-c', configPath, 'update'], execOpts, function() {
      async.parallel([
        function(callback) {
          execFile('supervisorctl', ['-c', configPath, 'kill', 'HUP', 'nginx-router'], execOpts, callback);
        },
        function(callback) {
          execFile('supervisorctl', ['-c', configPath, 'kill', 'HUP', 'web-nginx'], execOpts, callback);
        },
        function(callback) {
          execFile('supervisorctl', ['-c', configPath, 'kill', 'USR2', 'web-puma'], execOpts, callback);
        },
        function(callback) {
          execFile('supervisorctl', ['-c', configPath, 'serialrestart', 'gatekeeper:*'], execOpts, callback);
        },
        function(callback) {
          execFile('supervisorctl', ['-c', configPath, 'restart', 'config-reloader', 'distributed-rate-limits-sync', 'log-processor', 'router-log-listener'], execOpts, callback);
        },
      ], function(error) {
        if(error) {
          console.error('Error reloading: ', error);
        }
      });
    }.bind(this));
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
    mkdirp.sync(path.join(this.config.get('db_dir'), 'elasticsearch'));
    mkdirp.sync(path.join(this.config.get('db_dir'), 'mongodb'));
    mkdirp.sync(path.join(this.config.get('db_dir'), 'redis'));
    mkdirp.sync(path.join(this.config.get('log_dir'), 'supervisor'));
    mkdirp.sync(path.join(this.config.get('run_dir'), 'varnish/api-umbrella'));
    callback();
  },

  internalConfigDefaults: function(callback) {
    var filePath = path.join(this.config.get('run_dir'), 'internal_config_defaults.yml');
    var defaults = yaml.safeDump({
      internal_apis: [
        {
          _id: 'api-umbrella-web-backend',
          name: 'API Umbrella - Default',
          frontend_host: '*',
          backend_host: 'localhost',
          backend_protocol: 'http',
          balance_algorithm: 'least_conn',
          sort_order: 1,
          servers: [
            {
              _id: uuid.v4(),
              host: 'localhost',
              port: this.config.get('web.port'),
            }
          ],
          url_matches: [
            {
              _id: uuid.v4(),
              frontend_prefix: '/api-umbrella/',
              backend_prefix: '/api-umbrella/',
            }
          ],
          sub_settings: [
            {
              _id: uuid.v4(),
              http_method: 'post',
              regex: '^/api-umbrella/v1/users',
              settings: {
                _id: uuid.v4(),
                required_roles: ['api-umbrella-key-creator'],
              },
            },
            {
              _id: uuid.v4(),
              http_method: 'post',
              regex: '^/api-umbrella/v1/contact',
              settings: {
                _id: uuid.v4(),
                required_roles: ['api-umbrella-contact-form'],
              },
            },
          ],
        },
      ],
    });

    fs.writeFile(filePath, defaults, function(error) {
      if(error) { return callback(error); }

      this.configLoader.options.paths.push(filePath);
      this.configLoader.reload(callback);
    }.bind(this));
  },

  setupGlobalConfig: function(callback) {
    apiUmbrellaConfig.setGlobal(this.configLoader.runtimeFile);
    processEnv.env['API_UMBRELLA_CONFIG'] = this.configLoader.runtimeFile;
    callback();
  },

  seedDatabase: function(callback) {
    async.series([
      function(seriesCallback) {
        var email = 'web.admin.ajax@internal.apiumbrella';
        ApiUser.findOne({ email: email }, function(error, user) {
          if(error) { return seriesCallback(error); }

          if(!user) {
            user = new ApiUser({ _id: uuid.v4(), email: email });
          }

          user.set({
            first_name: 'API Umbrella Admin',
            last_name: 'Key',
            website: 'http://' + this.config.get('default_host') + '/',
            use_description: 'An API key for the API Umbrella admin to use for internal ajax requests.',
            terms_and_conditions: '1',
            registration_source: 'seed',
            settings: {
              _id: uuid.v4(),
              rate_limit_mode: 'unlimited',
            },
          });

          user.save(seriesCallback);
        }.bind(this));
      }.bind(this),
      function(seriesCallback) {
        var email = 'static.site.ajax@internal.apiumbrella';
        ApiUser.findOne({ email: email }, function(error, user) {
          if(error) { return seriesCallback(error); }

          if(!user) {
            user = new ApiUser({ _id: uuid.v4(), email: email });
          }

          user.set({
            first_name: 'API Umbrella Static Site',
            last_name: 'Key',
            website: 'http://' + this.config.get('default_host') + '/',
            use_description: 'An API key for the API Umbrella static website to use for ajax requests.',
            terms_and_conditions: '1',
            registration_source: 'seed',
            roles: ['api-umbrella-key-creator', 'api-umbrella-contact-form'],
            settings: {
              _id: uuid.v4(),
              rate_limit_mode: 'custom',
              rate_limits: [
                {
                  _id: uuid.v4(),
                  duration: 1 * 60 * 1000, // 1 minute
                  accuracy: 5 * 1000, // 5 seconds
                  limit_by: 'ip',
                  limit: 5,
                  response_headers: false,
                },
                {
                  _id: uuid.v4(),
                  duration: 60 * 60 * 1000, // 1 hour
                  accuracy: 1 * 60 * 1000, // 1 minute
                  limit_by: 'ip',
                  limit: 20,
                  response_headers: true,
                },
              ],
            },
          });

          this.staticSiteApiUser = user;
          user.save(seriesCallback);
        }.bind(this));
      }.bind(this),
    ], callback);;
  },

  writeTemplates: function(callback) {
    var templateConfig = _.extend({}, this.config.getAll(), {
      api_umbrella_config_args: '--config ' + this.configLoader.runtimeFile,
      gatekeeper_hosts: _.times(this.config.get('gatekeeper.workers'), function(n) { return '127.0.0.1:' + (50000 + n); }),
      test_env: (this.config.get('app_env') == 'test'),
      development_env: (this.config.get('app_env') == 'development'),
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
    this.supervisordProcess = new (forever.Monitor)(['supervisord', '-c', processEnv.supervisordConfigPath, '--nodaemon'], {
      max: 1,
      silent: true,
      logFile: path.join(this.config.get('log_dir'), 'supervisor/supervisord_forever.log'),
      outFile: path.join(this.config.get('log_dir'), 'supervisor/supervisord_forever.log'),
      errFile: path.join(this.config.get('log_dir'), 'supervisor/supervisord_forever.log'),
      append: true,
      env: processEnv.env,
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
      'unix://' + this.config.get('run_dir') + '/web-puma.sock',
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

  writeStaticSiteEnv: function(callback) {
    var envPath = '/vagrant/workspace/static-site/.env';
    var envLines = [];
    if(fs.existsSync(envPath)) {
      var env = fs.readFileSync(envPath);
      envLines = env.toString().split(/[\r\n]+/);
    }

    var apiKeyLine = 'API_UMBRELLA_API_KEY=' + this.staticSiteApiUser.api_key;
    if(envLines.indexOf(apiKeyLine) === -1) {
      envLines = _.reject(envLines, function(line) {
        return line.indexOf('API_UMBRELLA_API_KEY=') === 0;
      });

      envLines.push(apiKeyLine);
      fs.writeFile(envPath, envLines.join('\n'), function(error) {
        if(error) { return callback(error); }

        if(this.config.get('app_env') == 'development') {
          execFile('supervisorctl', ['-c', configPath, 'restart', 'static-site'], {
            env: processEnv.env,
          }, callback);
        } else {
          execFile('bundle', ['exec', 'middleman', 'build'], {
            cwd: '/vagrant/workspace/static-site',
            env: processEnv.env,
          }, callback);
        }
      }.bind(this));
    } else {
      callback();
    }
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
});
