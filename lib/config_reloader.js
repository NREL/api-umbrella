'use strict';

var _ = require('lodash'),
    async = require('async'),
    cloneDeep = require('clone'),
    config = require('./config'),
    ConfigVersion = require('./models/config_version'),
    DnsResolver = require('./config_reloader/dns_resolver').DnsResolver,
    events = require('events'),
    exec = require('child_process').exec,
    fs = require('fs'),
    handlebars = require('handlebars'),
    logger = require('./logger'),
    mongoConnect = require('./mongo_connect'),
    path = require('path'),
    traverse = require('traverse'),
    util = require('util');

var ConfigReloader = function() {
  this.initialize.apply(this, arguments);
};

util.inherits(ConfigReloader, events.EventEmitter);
_.extend(ConfigReloader.prototype, {
  initialize: function(readyCallback) {
    var templatePath = path.resolve(__dirname, '../templates/nginx.hbs');
    var templateContent = fs.readFileSync(templatePath);
    this.nginxTemplate = handlebars.compile(templateContent.toString());

    if(readyCallback) {
      this.once('reloaded', readyCallback);
    }

    async.parallel([
      this.connectMongo.bind(this),
      this.setupDnsResolver.bind(this),
    ], this.handleStartup.bind(this));
  },

  connectMongo: function(asyncReadyCallback) {
    mongoConnect(asyncReadyCallback);
  },

  setupDnsResolver: function(asyncReadyCallback) {
    this.resolver = new DnsResolver(this, asyncReadyCallback);
  },

  handleStartup: function(error) {
    if(error) {
      logger.error('Config reloader startup error: ', error);
      process.exit(1);
      return false;
    }

    // Force a reload on initial boot (in case internal changes have been made
    // that would affect the output even if the configuration values haven't
    // changed).
    this.reload({ force: true });
  },

  reload: function(options) {
    ConfigVersion
      .find()
      .sort({ version: -1 })
      .limit(1)
      .exec(this.handleFetchConfigVersion.bind(this, options));
  },

  handleFetchConfigVersion: function(options, error, configVersions) {
    if(configVersions) {
      this.lastConfig = configVersions[0];
    }

    this.apis = [];
    if(config.getOriginal('apis')) {
      this.apis.concat(config.getOriginal('apis'));
    }

    if(this.lastConfig && this.lastConfig.config.apis) {
      this.apis = this.lastConfig.config.apis;
    }

    var lastId = null;
    if(this.lastConfig && this.lastConfig._id) {
      lastId = this.lastConfig._id.toHexString();
    }

    var activeId = config.get('version_id');

    if((options && options.force) || (this.lastConfig && lastId !== activeId)) {
      logger.info('Writing new config...');
      this.writeConfigs();
    } else {
      this.poll();
    }
  },

  writeConfigs: function() {
    // Write nginx config's first.
    async.series([
      this.resolveHosts.bind(this),
      this.writeNginxConfig.bind(this),
      this.writeGatekeeperConfig.bind(this),
    ], this.handleWriteConfigs.bind(this));
  },

  resolveHosts: function(writeConfigsCallback) {
    logger.info('Resolving all hosts..');
    this.resolver.resolveAllHosts(this.handleResolveHosts.bind(this, writeConfigsCallback));
  },

  handleResolveHosts: function(writeConfigsCallback, error) {
    logger.info('Handle resolving all hosts..');
    writeConfigsCallback(error);

    // After resolving all the hosts, listen for one-off DNS changes for hosts
    // and re-write the nginx config file as needed.
    this.resolver.on('hostChanged', this.writeNginxConfig.bind(this));
  },

  writeNginxConfig: function(writeConfigsCallback) {
    logger.info('Writing nginx config...');

    var apis = _.reject(cloneDeep(this.apis), function(api) {
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

      api.servers.forEach(function(server) {
        server.ip = this.resolver.getIp(server.host);
      }.bind(this));
    }.bind(this));

    var newContent = this.nginxTemplate({
      logDir: config.logDir,
      hosts: frontendHosts,
      apis: apis,
    });

    var nginxPath = path.join(config.configDir, 'nginx.conf');

    var write = function() {
      fs.writeFile(nginxPath, newContent, function(error) {
        if(error) {
          logger.error('Error writing nginx config: ', error);
          if(writeConfigsCallback) {
            writeConfigsCallback(error);
          }

          return false;
        }

        logger.info('Nginx config written...');

        this.emit('nginx');

        this.reloadNginx(writeConfigsCallback);
      }.bind(this));
    }.bind(this);

    fs.exists(nginxPath, function(exists) {
      if(exists) {
        fs.readFile(nginxPath, function(error, data) {
          var oldContent = data.toString();
          if(oldContent === newContent) {
            logger.info('Nginx config already up-to-date - skipping...');

            if(writeConfigsCallback) {
              writeConfigsCallback(null);
            }
          } else {
            write();
          }
        });
      } else {
        write();
      }
    });
  },

  reloadNginx: function(writeConfigsCallback) {
    logger.info('Reloading nginx...');
    exec('sudo /etc/init.d/nginx configtest && sudo /etc/init.d/nginx reload', function(error, stdout, stderr) {
      if(error) {
        logger.error('Error reloading nginx: ', error, stderr, stdout);
      }

      logger.info('Nginx reloaded... ', stdout + ' ' + stderr);

      if(writeConfigsCallback) {
        writeConfigsCallback(null);
      }
    });
  },

  writeGatekeeperConfig: function(writeConfigsCallback) {
    logger.info('Writing gatekeeper config...');

    config.reset({ quiet: true });

    if(this.lastConfig) {
      var values = cloneDeep(this.lastConfig.config);
      traverse(values).forEach(function(value) {
        if(value && value._bsontype && value._bsontype === 'ObjectID') {
          this.update(value.toHexString());
        }
      });

      _.extend(values, {
        version_id: this.lastConfig._id.toHexString(),
        version: this.lastConfig.version,
      });

      config.updateRuntime({ apiUmbrella: values }, { quiet: true });
    } else {
      logger.info('No gatekeeper config changes found - reseting...');
    }

    config.saveRuntime(function(error) {
      if(error) {
        logger.error('Error writing gatekeeper config: ', error);
        writeConfigsCallback(error);
        return false;
      }

      logger.info('Gatekeeper config written...');
      writeConfigsCallback(null);
    });
  },

  handleWriteConfigs: function(error) {
    if(error) {
      logger.error('Error writing configs: ', error);
    } else {
      logger.info('Config files written...');
      this.emit('reloaded');
    }

    this.poll();
  },

  // FIXME: We're polling for configuration changes from mongoid right now. Not
  // polling would obviously be better. Using something like Zookeeper might be
  // appropriate to better ensure all nodes are running the same config
  // versions at the same time. We could also use Zookeeper to store the active
  // config version on each node so the web admin could more easily keep track
  // of when publishing is complete to all the active nodes.
  poll: function() {
    this.pollTimeout = setTimeout(this.reload.bind(this), 500);
  },

  close: function(callback) {
    if(this.pollTimeout) {
      clearTimeout(this.pollTimeout);
    }

    if(mongoose.connection) {
      mongoose.connection.close();
    }

    if(this.resolver) {
      this.resolver.close();
    }

    if(callback) {
      callback(null);
    }
  },
});

module.exports.ConfigReloader = ConfigReloader;
