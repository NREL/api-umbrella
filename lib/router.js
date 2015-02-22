'use strict';

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    async = require('async'),
    clc = require('cli-color'),
    config = require('api-umbrella-config').global(),
    crypto = require('crypto'),
    events = require('events'),
    execFile = require('child_process').execFile,
    forever = require('forever-monitor'),
    fs = require('fs'),
    fsExtra = require('fs-extra'),
    glob = require('glob'),
    handlebars = require('handlebars'),
    mkdirp = require('mkdirp'),
    mongoose = require('mongoose'),
    net = require('net'),
    os = require('os'),
    path = require('path'),
    posix = require('posix'),
    processEnv = require('./process_env'),
    procps = require('procps'),
    request = require('request'),
    supervisord = require('supervisord'),
    url = require('url'),
    util = require('util'),
    uuid = require('node-uuid'),
    yaml = require('js-yaml');

// Defer loading some internal dependencies until the config file is loaded (so
// we can ensure the global config is available for any of our internal
// libraries).
var mongoConnect,
    Admin,
    ApiUser;

var Router = function() {
  this.initialize.apply(this, arguments);
};

util.inherits(Router, events.EventEmitter);
_.extend(Router.prototype, {
  initialize: function(options) {
    this.startingInProgress = true;

    process.stdout.write('Starting api-umbrella...');
    this.startWaitLog = setInterval(function() {
      process.stdout.write('.');
    }, 2000);

    process.on('SIGHUP', this.reload.bind(this));
    process.on('SIGUSR2', this.reopenLogs.bind(this));
    process.on('SIGINT', this.stop.bind(this, function() {
      process.exit(0);
    }));

    apiUmbrellaConfig.loader({
      defaults: {},
      paths: [
        path.resolve(__dirname, '../config/default.yml'),
        path.resolve(__dirname, '../config/default.local.yml'),
      ].concat(options.config),
    }, this.handleConfigReady.bind(this));
  },

  handleConfigReady: function(error, configLoader) {
    this.configLoader = configLoader;

    async.series([
      this.setupGlobalConfig.bind(this),
      this.permissionCheck.bind(this),
      this.checkFreeMemory.bind(this),
      this.setResourceLimits.bind(this),
      this.internalConfigDefaults.bind(this),
      this.computedConfigValues.bind(this),
      this.cachedRandomConfigValues.bind(this),
      this.reloadGlobalConfig.bind(this),
      this.requireDeferredDependencies.bind(this),
      this.prepare.bind(this),
      this.writeTemplates.bind(this),
      this.startSupervisor.bind(this),
      this.waitForProcesses.bind(this),
      this.waitForConnections.bind(this),
      this.mongoConnect.bind(this),
      this.preMigrateNewDatabaseRouter.bind(this),
      this.preMigrateNewDatabaseWeb.bind(this),
      this.migrateDatabaseRouter.bind(this),
      this.migrateDatabaseWeb.bind(this),
      this.seedDatabase.bind(this),
      this.writeStaticSiteEnv.bind(this),
    ], this.finishStart.bind(this));
  },

  reload: function() {
    var logger = require('./logger'),
        reload = require('./reload');

    var options = {};
    var reloadOptionsPath = path.join(os.tmpdir(), 'api-umbrella-reload-options.json');
    if(fs.existsSync(reloadOptionsPath)) {
      var optionsContent = fs.readFileSync(reloadOptionsPath);
      if(optionsContent) {
        options = JSON.parse(optionsContent);
      }
      fs.unlinkSync(reloadOptionsPath);
    }

    async.series([
      this.configLoader.reload.bind(this.configLoader),
      this.writeTemplates.bind(this),
      reload.bind(this, options),
    ], function(error) {
      if(error) {
        logger.error('Error reloading: ', error);
        return false;
      }
    });
  },

  reopenLogs: function() {
    var logger = require('./logger');
    var configPath = processEnv.supervisordConfigPath();
    var execOpts = {
      env: processEnv.env(),
    };

    logger.info('Begin reopening api-umbrella logs...');
    var tasks = [
      function(callback) {
        logger.info('Reopening logs for supervisord...');
        var pidPath = path.join(config.get('run_dir'), 'supervisord.pid');
        fs.readFile(pidPath, function(error, data) {
          if(error) {
            return callback(error);
          }

          if(!data || !data.toString().trim()) {
            return callback('Could not determine pid of supervisord');
          }

          execFile('kill', ['-USR2', data.toString().trim()], execOpts, callback);
        });
      },
    ];

    if(config.get('service_router_enabled')) {
      tasks = tasks.concat([
        function(callback) {
          logger.info('Reopening logs for router-nginx...');
          execFile('supervisorctl', ['-c', configPath, 'kill', 'USR1', 'router-nginx'], execOpts, callback);
        },
        function(callback) {
          logger.info('Reopening logs for varnishncsa...');
          execFile('supervisorctl', ['-c', configPath, 'kill', 'HUP', 'varnishncsa'], execOpts, callback);
        },
      ]);
    }

    if(config.get('service_web_enabled')) {
      tasks = tasks.concat([
        function(callback) {
          logger.info('Reopening logs for web-nginx...');
          execFile('supervisorctl', ['-c', configPath, 'kill', 'USR1', 'web-nginx'], execOpts, callback);
        },
      ]);
    }

    if(tasks.length > 0) {
      async.parallel(tasks, function(error) {
        if(error) {
          logger.error({ err: error }, 'Error reopening log files');
          return false;
        }
        logger.info('Finished reopening api-umbrella logs');
      });
    }
  },

  stop: function(callback) {
    this.stopCallback = callback;

    process.stdout.write('\nStopping api-umbrella...');

    if(this.configLoader) {
      this.configLoader.close();
    }

    if(mongoose && mongoose.connection) {
      mongoose.connection.close();
    }

    if(this.supervisordProcess && this.supervisordProcess.running) {
      this.supervisordProcess.stop();
    } else {
      this.finishStop();
    }
  },

  prepare: function(callback) {
    mkdirp.sync(path.join(config.get('db_dir'), 'beanstalkd'));
    mkdirp.sync(path.join(config.get('db_dir'), 'elasticsearch'));
    mkdirp.sync(path.join(config.get('db_dir'), 'mongodb'));
    mkdirp.sync(path.join(config.get('db_dir'), 'redis'));
    mkdirp.sync(path.join(config.get('etc_dir'), 'elasticsearch'));
    mkdirp.sync(path.join(config.get('etc_dir'), 'nginx'));
    mkdirp.sync(path.join(config.get('log_dir')));
    mkdirp.sync(path.join(config.get('run_dir'), 'varnish/api-umbrella'));
    mkdirp.sync(config.get('tmp_dir'), { mode: parseInt('0777', 8) });

    if(config.get('user')) {
      var uid = posix.getpwnam(config.get('user')).uid;
      var gid = posix.getgrnam(config.get('group')).gid;

      fs.chownSync(path.join(config.get('db_dir'), 'beanstalkd'), uid, gid);
      fs.chownSync(path.join(config.get('db_dir'), 'elasticsearch'), uid, gid);
      fs.chownSync(path.join(config.get('db_dir'), 'mongodb'), uid, gid);
      fs.chownSync(path.join(config.get('db_dir'), 'redis'), uid, gid);
      fs.chownSync(path.join(config.get('run_dir'), 'varnish'), uid, gid);
      fs.chownSync(path.join(config.get('run_dir'), 'varnish/api-umbrella'), uid, gid);
      fs.chownSync(config.get('tmp_dir'), uid, gid);
    }

    var primaryHostsNoSsl = _.filter(config.get('hosts'), function(host) {
      return !host.secondary && !host.ssl_cert;
    });

    var sslDir = path.join(config.get('etc_dir'), 'ssl');
    var sslKeyPath = path.join(sslDir, 'self_signed.key');
    var sslCrtPath = path.join(sslDir, 'self_signed.crt');

    var generateSelfSignedCert = false;
    if(primaryHostsNoSsl.length > 0) {
      if(!fs.existsSync(sslKeyPath) || !fs.existsSync(sslCrtPath)) {
        generateSelfSignedCert = true;
      }
    }

    if(generateSelfSignedCert) {
      mkdirp.sync(sslDir);
      execFile('openssl', [
        'req',
        '-new',
        '-newkey', 'rsa:2048',
        '-days', 365 * 5,
        '-nodes',
        '-x509',
        '-subj', '/C=/ST=/L=/O=API Umbrella/CN=apiumbrella.example.com',
        '-keyout', sslKeyPath,
        '-out', sslCrtPath,
      ], {
        env: processEnv.env(),
      }, callback);
    } else {
      callback();
    }
  },

  internalConfigDefaults: function(callback) {
    var filePath = path.join(config.get('run_dir'), 'internal_config_defaults.yml');
    var defaults = yaml.safeDump({
      internal_apis: [
        {
          _id: 'api-umbrella-web-backend',
          name: 'API Umbrella - Default',
          frontend_host: '*',
          backend_host: '127.0.0.1',
          backend_protocol: 'http',
          balance_algorithm: 'least_conn',
          sort_order: 1,
          servers: [
            {
              _id: uuid.v4(),
              host: '127.0.0.1',
              port: config.get('web.port'),
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

  computedConfigValues: function(callback) {
    var filePath = path.join(config.get('run_dir'), 'computed_config_values.yml');
    var defaults = {
      service_general_db_enabled: _.contains(config.get('services'), 'general_db'),
      service_log_db_enabled: _.contains(config.get('services'), 'log_db'),
      service_router_enabled: _.contains(config.get('services'), 'router'),
      service_web_enabled: _.contains(config.get('services'), 'web'),
      router: {
        trusted_proxies: ['127.0.0.1'].concat(config.get('router.trusted_proxies') || []),
      },
    };

    if(config.get('static_site.dir') && !config.get('static_site.build_dir')) {
      _.merge(defaults, {
        static_site: {
          build_dir: path.join(config.get('static_site.dir'), 'build'),
        },
      });
    }

    fs.writeFile(filePath, yaml.safeDump(defaults), function(error) {
      if(error) { return callback(error); }

      this.configLoader.options.paths.push(filePath);
      this.configLoader.reload(callback);
    }.bind(this));
  },

  cachedRandomConfigValues: function(callback) {
    var filePath = path.join(config.get('run_dir'), 'cached_random_config_values.yml');
    var data = '';
    if(fs.existsSync(filePath)) {
      data = fs.readFileSync(filePath).toString();
    }

    var cached = yaml.safeLoad(data) || {};

    if(!config.get('web.rails_secret_token')) {
      cached = _.merge({
        web: {
          rails_secret_token: crypto.randomBytes(64).toString('hex'),
        },
      }, cached);
    }

    if(!config.get('web.devise_secret_key')) {
      cached = _.merge({
        web: {
          devise_secret_key: crypto.randomBytes(64).toString('hex'),
        },
      }, cached);
    }

    fs.writeFile(filePath, yaml.safeDump(cached), function(error) {
      if(error) { return callback(error); }

      this.configLoader.options.paths.push(filePath);
      this.configLoader.reload(callback);
    }.bind(this));
  },

  setupGlobalConfig: function(callback) {
    apiUmbrellaConfig.setGlobal(this.configLoader.runtimeFile);
    config = require('api-umbrella-config').global();

    // Don't poll for mongodb config changes unless we need to (the router and
    // child gatekeeper processes are the only things that need to be listening
    // for those runtime changes).
    if(!_.contains(config.get('services'), 'router')) {
      this.configLoader.close();
    }

    // A dance to move the runtime config file into a less temporary location.
    //
    // This could maybe be addressed better in the api-umbrella-config module,
    // but we want to install the runtime config file into a location based on
    // paths defined in the config file, so it's a little tricky.
    //
    // Copying the file also prevents a build-up of lots of temporary yaml
    // files, which is how api-umbrella-config will behave by default (since we
    // don't necessarily want api-umbrella-config to cleanup the files when it
    // closes, since other processes might be reading the files).
    var tempConfigPath = this.configLoader.runtimeFile;
    try {
      var permanentConfigPath = path.join(config.get('run_dir'), 'runtime_config.yml');
      fsExtra.copySync(tempConfigPath, permanentConfigPath);
      this.configLoader.runtimeFile = permanentConfigPath;
      apiUmbrellaConfig.setGlobal(this.configLoader.runtimeFile);
      config.reload();
    } finally {
      // Always cleanup the temp file, even if the app dies because
      // permanentConfigPath is not writable.
      fs.unlinkSync(tempConfigPath);
    }

    var overrides = {
      'API_UMBRELLA_CONFIG': this.configLoader.runtimeFile,
    };

    if(config.get('app_env') === 'test') {
      // In the test environment, we only want the log file location override
      // to take effect for the master test process being run (to prevent
      // output to stdout during the test runs). For all the other processes
      // that we spin up, we want them to log to their normal log locations.
      overrides['API_UMBRELLA_LOG_PATH'] = '';
    }

    processEnv.overrideEnv(overrides);

    callback();
  },

  reloadGlobalConfig: function(callback) {
    config.reload();
    callback();
  },

  requireDeferredDependencies: function(callback) {
    Admin = require('./models/admin');
    mongoConnect = require('./mongo_connect');

    var models = require('api-umbrella-gatekeeper').models(mongoose);
    ApiUser = models.ApiUser;

    callback();
  },

  permissionCheck: function(callback) {
    if(config.get('user')) {
      if(posix.geteuid() !== 0) {
        return callback('Must be started with super-user privileges to change user to \'' + config.get('user') + '\'');
      }

      try {
        posix.getpwnam(config.get('user'));
      } catch(e) {
        return callback('User \'' + config.get('user') + '\' does not exist');
      }
    }

    if(config.get('group')) {
      if(posix.geteuid() !== 0) {
        return callback('Must be started with super-user privileges to change group to \'' + config.get('group') + '\'');
      }

      try {
        posix.getgrnam(config.get('group'));
      } catch(e) {
        return callback('Group \'' + config.get('group') + '\' does not exist');
      }

      // Change the process group id so the api-umbrella-config file that gets
      // written is readable by the api-umbrella group.
      process.setgid(config.get('group'));
    }

    if(config.get('http_port') < 1024 || config.get('https_port') < 1024) {
      if(posix.geteuid() !== 0) {
        return callback('Must be started with super-user privileges to use http ports below 1024');
      }
    }

    if(posix.geteuid() === 0) {
      if(!config.get('user') || !config.get('group')) {
        return callback('Must define a user and group to run worker processes as when starting with with super-user privileges');
      }
    }

    callback();
  },

  checkFreeMemory: function(callback) {
    var meminfo = procps.sysinfo.meminfo('m');

    // Get the real amount of free memory, plus buffers/cached.
    var freeMem = meminfo.mainFree + meminfo.mainBuffers + meminfo.mainCached;
    var preferredFree = 1.5 * 1024; // 1.5 GB
    if(freeMem < preferredFree) {
      process.stderr.write('\n');
      var warning = 'System does not have at least 1.5 GB of free memory (' + freeMem + ' MB available). You may experience degraded performance.';
      console.warn('\nWARNING: ' + warning);

      var freeSwap = meminfo.swapFree;
      var preferredSwap = 1 * 1024;
      if(freeSwap < preferredSwap) {
        warning = 'System with low memory does not have at least 1GB of free swap (' + freeSwap + ' MB available). API Umbrella may fail to start.';
        console.warn('\nWARNING: ' + warning);
      }
    }

    callback();
  },

  setResourceLimits: function(callback) {
    ['nofile', 'nproc'].forEach(function(resource) {
      var newLimit = config.get('rlimits.' + resource);
      if(newLimit) {
        // In non-root environments attempt set the soft limit, but cap it at
        // the hard limit (the highest a non-root user can set it to).
        if(posix.geteuid() !== 0) {
          try {
            var existingLimits = posix.getrlimit(resource);
            if(newLimit > existingLimits.hard) {
              var warning = 'Not started as root, lowering resource limit \'' + resource + '\' from requested (' + newLimit + ') to maximum allowed (' + existingLimits.hard + ')\nFor optimal performance, raise the system-wide \'hard\' resource limit for \'' + resource + '\', or start as root';
              console.warn('\nWARNING: ' + warning);

              newLimit = existingLimits.hard;
            }
          } catch(error) {
            return callback('Could not fetch \'' + resource + '\' resource limit: ' + error);
          }
        }

        var limit = { soft: newLimit };
        if(posix.geteuid() === 0) {
          limit.hard = limit.soft;
        }

        try {
          posix.setrlimit(resource, limit);
        } catch(error) {
          return callback('Could not set \'' + resource + '\' resource limit: ' + error);
        }
      }
    });

    callback();
  },

  preMigrateNewDatabaseRouter: function(callback) {
    if(!config.get('service_router_enabled')) { return callback(); }

    var db = mongoose.connection.db;
    var collectionName = '_migrations';
    db.collection(collectionName, { strict: true }, function(error) {
      // If the collection doesn't yet exist, assume this is a new
      // installation, so we can mark all of our migrations as already done.
      if(error) {
        db.createCollection(collectionName, function(error, collection) {
          glob(path.resolve(__dirname, '../migrations/*.js'), function(error, migrationPaths) {
            if(error) { return callback(error); }

            var migrations = _.map(migrationPaths, function(migrationPath) {
              return {
                _id: path.basename(migrationPath, '.js'),
              };
            });

            collection.insert(migrations, callback);
          });
        });
      } else {
        callback();
      }
    });
  },

  preMigrateNewDatabaseWeb: function(callback) {
    if(!config.get('service_web_enabled')) { return callback(); }

    var db = mongoose.connection.db;
    var collectionName = 'data_migrations';
    db.collection(collectionName, { strict: true }, function(error) {
      // If the collection doesn't yet exist, assume this is a new
      // installation, so we can mark all of our migrations as already done.
      if(error) {
        db.createCollection(collectionName, function(error, collection) {
          glob(path.join(config.get('web.dir'), 'db/migrate/*.rb'), function(error, migrationPaths) {
            if(error) { return callback(error); }

            var migrations = _.map(migrationPaths, function(migrationPath) {
              return {
                version: path.basename(migrationPath, '.rb').split('_')[0],
              };
            });

            collection.insert(migrations, callback);
          });
        });
      } else {
        callback();
      }
    });
  },

  migrateDatabaseRouter: function(callback) {
    if(!config.get('service_router_enabled')) { return callback(); }

    execFile('east', ['migrate'], {
      cwd: path.resolve(__dirname, '../'),
      env: processEnv.env(),
    }, function(error, stdout, stderr) {
      if(error) {
        error.message = 'router migration error: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr;
      }

      callback(error);
    });
  },

  migrateDatabaseWeb: function(callback) {
    if(!config.get('service_web_enabled')) { return callback(); }

    execFile('bundle', [
      'exec',
      'rake',
      'db:mongoid:create_indexes',
      'db:migrate',
      'db:seed_fu',
    ], {
      cwd: config.get('web.dir'),
      env: processEnv.env(),
    }, function(error, stdout, stderr) {
      if(error) {
        error.message = 'web migration error: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr;
      }

      callback(error);
    });
  },

  seedDatabase: function(callback) {
    if(!config.get('service_router_enabled')) { return callback(); }

    async.series([
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
            website: 'http://' + config.get('default_host') + '/',
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
      function(seriesCallback) {
        async.each(config.get('web.admin.initial_superusers') || [], function(username, eachCallback) {
          Admin.findOne({ username: username }, function(error, admin) {
            if(error) { return eachCallback(error); }

            if(!admin) {
              admin = new Admin({ _id: uuid.v4(), username: username });
            }

            admin.set({
              superuser: true,
            });

            admin.save(eachCallback);
          });
        }, seriesCallback);
      }.bind(this),
    ], callback);
  },

  writeTemplates: function(callback) {
    var writeTemplates = require('./write_templates');
    writeTemplates(callback);
  },

  startSupervisor: function(callback) {
    this.supervisordProcess = new (forever.Monitor)(['supervisord', '-c', processEnv.supervisordConfigPath(), '--nodaemon'], {
      max: 1,
      silent: true,
      logFile: path.join(config.get('log_dir'), 'supervisord-forever.log'),
      outFile: path.join(config.get('log_dir'), 'supervisord-forever.log'),
      errFile: path.join(config.get('log_dir'), 'supervisord-forever.log'),
      append: true,
      env: processEnv.env(),
    });

    this.supervisordProcess.on('error', function() {
      console.info('error: ', arguments);
    });

    this.supervisordProcess.on('start', function() {
      callback();
    });

    this.supervisordProcess.on('exit', function() {
      if(this.startingInProgress) {
        callback('supervisord failed to start');
      } else {
        this.finishStop();
      }
    }.bind(this));

    this.supervisordProcess.start();
  },

  waitForProcesses: function(callback) {
    var client = supervisord.connect('http://127.0.0.1:' + config.get('supervisord.inet_http_server.port'));
    var connected = false;
    var nonRunningProcesses = [];
    var attemptDelay = 100;

    var timeout = setTimeout(function() {
      if(nonRunningProcesses.length > 0) {
        callback('Failed to start processes:\n' + _.map(nonRunningProcesses, function(process) {
          return '  ' + process.name + ' (' + process.statename + ' - ' + process.logfile + ')';
        }).join('\n'));
      } else {
        callback('Failed to start - no services enabled');
      }
    }.bind(this), 60000);
    timeout.unref();

    async.until(function() {
      return connected;
    }, function(untilCallback) {
      client.getAllProcessInfo(function(error, result) {
        if(result && _.isEqual(_.uniq(_.pluck(result, 'statename')), ['RUNNING'])) {
          connected = true;
          untilCallback();
        } else {
          nonRunningProcesses = _.filter(result, function(process) { return process.statename !== 'RUNNING'; });
          setTimeout(untilCallback, attemptDelay);
        }
      });
    }, function() {
      clearTimeout(timeout);
      callback();
    });
  },

  waitForConnections: function(callback) {
    var listeners = [];

    if(config.get('service_general_db_enabled')) {
      listeners = listeners.concat([
        'tcp://127.0.0.1:' + config.get('mongodb.embedded_server_config.net.port'),
      ]);
    }

    if(config.get('service_log_db_enabled')) {
      listeners = listeners.concat([
        'http://127.0.0.1:' + config.get('elasticsearch.embedded_server_config.http.port'),
      ]);
    }

    if(config.get('service_router_enabled')) {
      listeners = listeners.concat([
        'tcp://127.0.0.1:' + config.get('beanstalkd.port'),
        'tcp://127.0.0.1:' + config.get('dnsmasq.port'),
        'tcp://127.0.0.1:' + config.get('http_port'),
        'tcp://127.0.0.1:' + config.get('redis.port'),
        'tcp://127.0.0.1:' + config.get('varnish.port'),
      ]);
    }

    if(config.get('service_web_enabled')) {
      listeners = listeners.concat([
        'tcp://127.0.0.1:' + config.get('web.port'),
        'unix://' + config.get('run_dir') + '/web-puma.sock',
      ]);
    }

    var allConnected = (listeners.length === 0) ? true : false;
    var successfulConnections = [];

    var timeout = setTimeout(function() {
      callback('Unable to establish connections: ' + _.difference(listeners, successfulConnections).join(', '));
    }.bind(this), 200000);
    timeout.unref();

    async.each(listeners, function(listener, eachCallback) {
      var parsed = url.parse(listener);

      // Wait until we're able to establish a connection before moving on.
      var connected = false;
      var attemptDelay = 250;
      async.until(function() {
        return connected;
      }, function(untilCallback) {
        switch(parsed.protocol) {
          case 'http:':
            request({ url: parsed.href, timeout: 1500 }, function(error) {
              if(!error) {
                connected = true;
                successfulConnections.push(listener);
                untilCallback();
              } else {
                setTimeout(untilCallback, attemptDelay);
              }
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
              setTimeout(untilCallback, attemptDelay);
            });
            break;
        }
      }, eachCallback);
    }, function() {
      allConnected = true;
      clearTimeout(timeout);
      callback();
    });
  },

  mongoConnect: function(callback) {
    mongoConnect(callback);
  },

  writeStaticSiteEnv: function(callback) {
    if(!config.get('service_router_enabled')) { return callback(); }

    // Re-process the static site env template now that the api key has been
    // created for it.
    var templatePath = path.resolve(__dirname, '../templates/etc/static_site_env.hbs');
    var installPath = path.join(config.get('etc_dir'), 'static_site_env');

    var content = fs.readFileSync(templatePath).toString();
    var template = handlebars.compile(content);
    content = template({
      static_site_api_key: this.staticSiteApiUser.api_key,
    });

    fs.writeFileSync(installPath, content);

    if(config.get('app_env') === 'development') {
      execFile('supervisorctl', ['-c', processEnv.supervisordConfigPath(), 'restart', 'static-site'], {
        env: processEnv.env(),
      }, function(error, stdout, stderr) {
        if(error) {
          error.message = 'middleman restart error: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr;
        }

        callback(error);
      });
    } else {
      execFile('bundle', ['exec', 'middleman', 'build', '--verbose'], {
        cwd: config.get('static_site.dir'),
        env: _.merge({}, processEnv.env(), {
          'DOTENV_PATH': installPath,
          'BUILD_DIR': config.get('static_site.build_dir'),
        }),
      }, function(error, stdout, stderr) {
        if(error) {
          error.message = 'middleman build error: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr;
        }

        callback(error);
      });
    }
  },

  finishStart: function(error) {
    this.startingInProgress = false;

    if(error) {
      console.info(' [' + clc.red('FAIL') + ']\n');
      console.error(error);
      if(error.stack) {
        console.error(error.stack);
      }

      if(this.supervisordProcess) {
        console.error('\n  See ' + this.supervisordProcess.logFile + ' for more details');
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
