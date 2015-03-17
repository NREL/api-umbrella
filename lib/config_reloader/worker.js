'use strict';

var _ = require('lodash'),
    async = require('async'),
    cloneDeep = require('clone'),
    config = require('api-umbrella-config').global(),
    DnsResolver = require('./dns_resolver').DnsResolver,
    escapeRegexp = require('escape-regexp'),
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

    var frontendTemplatePath = path.resolve(__dirname, '../../templates/etc/nginx/frontend_hosts.conf.hbs');
    var frontendTemplateContent = fs.readFileSync(frontendTemplatePath);
    this.nginxFrontendTemplate = handlebars.compile(frontendTemplateContent.toString());

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
      this.writeNginxFrontendConfig.bind(this),
      this.writeNginxConfig.bind(this),
      this.reloadNginxOnChange.bind(this),
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

  writeNginxFrontendConfig: function(writeConfigsCallback) {
    logger.info('Writing nginx frontend config...');

    this.nginxConfigChanged = false;

    // Organize the known hosts (from the config file) by hostname.
    var hosts = {};
    var hostsConfig = cloneDeep(config.get('hosts'));
    hostsConfig.forEach(function(hostConfig) {
      if(!hostConfig.hostname) {
        hostConfig.hostname = '*';
      }

      hosts[hostConfig.hostname] = hostConfig;
    });

    // Fetch all the valid API backends config.
    this.apis = config.get('internal_apis') || [];
    this.apis = this.apis.concat(config.get('apis') || []);
    this.apis = cloneDeep(this.apis);
    this.apis = _.reject(this.apis, function(api) {
      return (!api.servers || api.servers.length === 0);
    });

    // Search each API backends config to discover new hostnames that are being
    // used and the URL prefixes in use on each hostname.
    this.apis.forEach(function(api) {
      var hostname = '*';
      if(api.frontend_host && api.frontend_host !== '*') {
        hostname = api.frontend_host.split(':')[0];
      }

      if(!hosts[hostname]) {
        hosts[hostname] = {
          hostname: hostname,
        };
      }

      if(api.url_matches) {
        // Collect all URL prefixes in use by this host.
        var prefixes = hosts[hostname].api_url_prefixes || [];
        prefixes = prefixes.concat(_.compact(_.map(api.url_matches, function(urlMatch) {
          var prefix;
          if(urlMatch.frontend_prefix) {
            prefix = urlMatch.frontend_prefix;

            // Sanity check that all prefixes start with a slash.
            if(prefix[0] !== '/') {
              prefix = '/' + prefix;
            }

            prefix = escapeRegexp(prefix);
          }

          return prefix;
        })));

        hosts[hostname].api_url_prefixes = prefixes;
      }
    });

    // For all the wildcard URL prefixes we've seen, these are valid across all
    // API hosts, so append these to all known hosts.
    var wildCardPrefixes = [];
    if(hosts['*'] && hosts['*'].api_url_prefixes) {
      wildCardPrefixes = hosts['*'].api_url_prefixes;
    }
    _.each(hosts, function(hostConfig) {
      var prefixes = hostConfig.api_url_prefixes || [];
      prefixes = prefixes.concat(wildCardPrefixes);
      prefixes = _.uniq(prefixes);
      hostConfig.api_url_prefixes = prefixes;
    });

    // If we have a host marked as the default, then this will get the nginx
    // "default_server" treatment, in which case, we don't need a wildcard host
    // in nginx (since all of the wildcard URL prefixes will already belong to
    // this default hostname.
    var defaultHost = _.where(config.get('hosts'), { default: true })[0];
    if(defaultHost && hosts['*'] && defaultHost.hostname !== '*') {
      delete hosts['*'];
    }

    // If we still have a separate wildcard host, set it's hostname to "_" for
    // nginx fallback matching.
    if(hosts['*']) {
      hosts['*'].hostname = '_';
    }

    // Now that we know each of the hosts and each of the URL prefixes those
    // hosts are responsible for, we can assemble the regex for matching the
    // prefixes on each host which we'll then pass to nginx.
    _.each(hosts, function(hostConfig) {
      if(hostConfig.api_url_prefixes) {
        hostConfig.api_url_prefixes_matcher = '^(' + hostConfig.api_url_prefixes.join('|') + ')';
        delete hostConfig.api_url_prefixes;
      }
    });

    var templateConfig = _.extend({}, config.getAll(), {
      hosts: _.values(hosts),
    });

    var newContent = this.nginxFrontendTemplate(templateConfig);

    var nginxPath = path.join(config.get('etc_dir'), 'nginx/frontend_hosts.conf');

    var write = function() {
      fs.writeFile(nginxPath, newContent, function(error) {
        if(error) {
          logger.error({ err: error }, 'Error writing nginx frontend config');
          if(writeConfigsCallback) {
            writeConfigsCallback(error);
          }

          return false;
        }

        logger.info('nginx frontend config written...');
        this.nginxConfigChanged = true;
        writeConfigsCallback();
      }.bind(this));
    }.bind(this);

    fs.exists(nginxPath, function(exists) {
      if(exists) {
        fs.readFile(nginxPath, function(error, data) {
          var oldContent = data.toString();
          if(oldContent === newContent) {
            logger.info('nginx frontend config already up-to-date - skipping...');

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

  writeNginxConfig: function(writeConfigsCallback) {
    logger.info('Writing nginx config...');

    this.apis.forEach(function(api) {
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
      apis: this.apis,
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
        this.nginxConfigChanged = true;
        writeConfigsCallback();
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

  reloadNginxOnChange: function(writeConfigsCallback) {
    if(this.nginxConfigChanged) {
      this.emit('nginx');
      this.reloadNginx(writeConfigsCallback);
    }
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
