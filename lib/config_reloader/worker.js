'use strict';

var _ = require('lodash'),
    async = require('async'),
    cloneDeep = require('clone'),
    config = require('api-umbrella-config').global(),
    DnsResolver = require('./dns_resolver').DnsResolver,
    events = require('events'),
    execFile = require('child_process').execFile,
    fs = require('fs'),
    handlebars = require('handlebars'),
    ipaddr = require('ipaddr.js'),
    logger = require('../logger'),
    path = require('path'),
    processEnv = require('../process_env'),
    util = require('util');

var Worker = function() {
  this.initialize.apply(this, arguments);
};

module.exports.Worker = Worker;

util.inherits(Worker, events.EventEmitter);
_.extend(Worker.prototype, {
  initialize: function(options) {
    logger.info('Worker init');
    this.options = options;

    this.once('reloaded', function() {
      this.emit('ready');
    }.bind(this));

    var templatePath = path.resolve(__dirname, '../../templates/etc/nginx/api_backends.conf.hbs');
    var templateContent = fs.readFileSync(templatePath);
    this.nginxTemplate = handlebars.compile(templateContent.toString());

    async.parallel([
      this.setupDnsResolver.bind(this),
    ], this.handleStartup.bind(this));
  },

  setupDnsResolver: function(asyncReadyCallback) {
    new DnsResolver(this, function(error, resolver) {
      this.resolver = resolver;
      asyncReadyCallback(error);
    }.bind(this));
  },

  handleStartup: function(error) {
    logger.info('Handle startup');
    if(error) {
      logger.error({ err: error }, 'Config reloader startup error');
      process.exit(1);
      return false;
    }

    this.resolver.on('hostChanged', this.handleHostDnsChange.bind(this));

    this.writeConfigs();
    config.on('change', this.writeConfigs.bind(this));

    // Keep this process alive indefinitely waiting for config changes.
    // (the DNS change pollers are normally enough to keep the process from
    // exiting after starting up, but when there's no domain names to resolve,
    // we need something to keep the api-umbrella-config's file watcher
    // active so we can respond to config changes)
    setInterval(function() {}, Math.POSITIVE_INFINITY);
  },

  writeConfigs: function() {
    logger.info('Write configs');
    // Write nginx config's first.
    async.series([
      this.resolveAllHosts.bind(this),
      this.writeNginxConfig.bind(this),
    ], this.handleWriteConfigs.bind(this));
  },

  resolveAllHosts: function(writeConfigsCallback) {
    logger.info('Resolving all hosts..');
    this.resolver.resolveAllHosts(writeConfigsCallback);
  },

  handleHostDnsChange: function() {
    if(this.hostChangedReloadNginxTimeout) {
      logger.info('IP changes - reload already scheduled');
    } else {
      var reloadIn = 0;

      // Prevent a problematic host from constantly reloading the server in
      // quick succession.
      if(this.reloadedRecently) {
        reloadIn = config.get('dns_resolver.reload_buffer_time') * 1000;
      }

      logger.info('IP changes - scheduling reloading in ' + reloadIn + 'ms');
      this.hostChangedReloadNginxTimeout = setTimeout(function() {
        this.reloadedRecently = true;
        this.hostChangedReloadNginxTimeout = null;
        logger.info('IP changes - reloading now');
        this.writeNginxConfig(function() {
          setTimeout(function() {
            this.reloadedRecently = false;
          }.bind(this), config.get('dns_resolver.reload_buffer_time'));
        }.bind(this));
      }.bind(this), reloadIn);
    }
  },

  writeNginxConfig: function(writeConfigsCallback) {
    logger.info('Writing nginx config...');

    var apis = config.get('internal_apis') || [];
    apis = apis.concat(config.get('apis') || []);
    apis = cloneDeep(apis);

    apis = _.reject(apis, function(api) {
      return (!api.servers || api.servers.length === 0);
    });

    apis.forEach(function(api) {
      if(api.balance_algorithm === 'least_conn' || api.balance_algorithm === 'ip_hash') {
        api.defaultBalance = false;
      } else {
        api.defaultBalance = true;
      }

      if(!api.keepalive_connections) {
        api.keepalive_connections = 10;
      }

      api.servers.forEach(function(server) {
        var resolvedServers = this.resolver.getServers(server.host);
        server.nginx_servers = _.map(resolvedServers, function(resolved) {
          var nginxServer = '';
          if(ipaddr.IPv6.isValid(resolved.address)) {
            nginxServer += '[' + resolved.address + ']';
          } else {
            nginxServer += resolved.address;
          }

          nginxServer += ':' + server.port;

          if(resolved.down) {
            nginxServer += ' down';
          }

          return nginxServer;
        });
      }.bind(this));

      logger.info(_.pick(api, 'servers', 'balance_algorithm', 'keepalive_connections'), 'API');
    }.bind(this));

    var templateConfig = _.extend({}, config.getAll(), {
      apis: apis,
    });

    var newContent = this.nginxTemplate(templateConfig);

    var nginxPath = path.join(config.get('etc_dir'), 'nginx/api_backends.conf');

    var write = function() {
      fs.writeFile(nginxPath, newContent, function(error) {
        if(error) {
          logger.error({ err: error }, 'Error writing nginx config');
          if(writeConfigsCallback) {
            writeConfigsCallback(error);
          }

          return false;
        }

        logger.info('nginx config written...');

        this.emit('nginx');

        this.reloadNginx(writeConfigsCallback);
      }.bind(this));
    }.bind(this);

    fs.exists(nginxPath, function(exists) {
      if(exists) {
        fs.readFile(nginxPath, function(error, data) {
          var oldContent = data.toString();
          if(oldContent === newContent) {
            logger.info('nginx config already up-to-date - skipping...');

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

    execFile('nginx', ['-t', '-c', path.join(config.get('etc_dir'), 'nginx/router.conf')], processEnv.env(), function(error, stdout, stderr) {
      if(error) {
        logger.error({ err: error, stdout: stdout, stderr: stderr }, 'Syntax check for nginx failed');
        return writeConfigsCallback('Syntax check for nginx failed');
      }

      execFile('supervisorctl', ['-c', processEnv.supervisordConfigPath(), 'kill', 'HUP', 'router-nginx'], processEnv.env(), function(error, stdout, stderr) {
        if(error) {
          logger.error({ err: error, stdout: stdout, stderr: stderr }, 'Error reloading nginx');
          return writeConfigsCallback('Error reloading nginx');
        }

        logger.info({ stdout: stdout, stderr: stderr }, 'nginx reload signal sent');
        writeConfigsCallback(null);
      });
    });
  },

  handleWriteConfigs: function(error) {
    if(error) {
      logger.error({ err: error }, 'Error writing configs');
    } else {
      logger.info('Config files written...');
      this.emit('reloaded');
    }
  },

  close: function(callback) {
    if(this.pollTimeout) {
      clearTimeout(this.pollTimeout);
    }

    if(this.hostChangedReloadNginxTimeout) {
      clearTimeout(this.hostChangedReloadNginxTimeout);
    }

    if(this.resolver) {
      this.resolver.close();
    }

    if(callback) {
      callback(null);
    }
  },
});
