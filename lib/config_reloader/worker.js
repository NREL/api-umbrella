'use strict';

var _ = require('lodash'),
    async = require('async'),
    cloneDeep = require('clone'),
    config = require('api-umbrella-config').global(),
    diff = require('diff'),
    DnsResolver = require('./dns_resolver').DnsResolver,
    escapeRegexp = require('escape-regexp'),
    events = require('events'),
    execFile = require('child_process').execFile,
    fs = require('fs'),
    handlebars = require('handlebars'),
    logger = require('../logger'),
    path = require('path'),
    processEnv = require('../process_env'),
    supervisorSignal = require('../supervisor_signal'),
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
    this.nginxConfigWritesInProgress = 0;

    this.once('reloaded', function() {
      this.emit('ready');
    }.bind(this));

    var frontendTemplatePath = path.resolve(__dirname, '../../templates/etc/nginx/frontend_hosts.conf.hbs');
    var frontendTemplateContent = fs.readFileSync(frontendTemplatePath);
    this.nginxFrontendTemplate = handlebars.compile(frontendTemplateContent.toString());

    var templatePath = path.resolve(__dirname, '../../templates/etc/nginx/backends.conf.hbs');
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
    config.on('change', this.handleConfigChange.bind(this));

    // Keep this process alive indefinitely waiting for config changes.
    // (the DNS change pollers are normally enough to keep the process from
    // exiting after starting up, but when there's no domain names to resolve,
    // we need something to keep the api-umbrella-config's file watcher
    // active so we can respond to config changes)
    setInterval(function() {}, Math.POSITIVE_INFINITY);
  },

  handleConfigChange: function() {
    logger.info('runtime.yml config change detected...');
    this.writeConfigs();
  },

  writeConfigs: function() {
    logger.info('Writing configs...');
    async.series([
      this.resolveAllHosts.bind(this),
      this.writeNginxConfig.bind(this),
    ], this.handleWriteConfigs.bind(this));
  },

  resolveAllHosts: function(writeConfigsCallback) {
    logger.info('Resolving all hosts...');
    this.resolver.resolveAllHosts(function(error) {
      writeConfigsCallback(error);
    });
  },

  handleHostDnsChange: function(host, servers) {
    if(this.hostChangedReloadNginxTimeout) {
      logger.info({ host: host }, 'IP changes - reload already scheduled');
    } else {
      var reloadIn = 0;

      // Prevent a problematic host from constantly reloading the server in
      // quick succession.
      if(this.reloadedRecently) {
        reloadIn = config.get('dns_resolver.reload_buffer_time') * 1000;
      }

      logger.info({ host: host }, 'IP changes - scheduling reloading in ' + reloadIn + 'ms');
      this.hostChangedReloadNginxTimeout = setTimeout(function() {
        this.reloadedRecently = true;
        this.hostChangedReloadNginxTimeout = null;
        logger.info({ host: host }, 'IP changes - reloading now');
        this.writeNginxConfig(function() {
          setTimeout(function() {
            this.reloadedRecently = false;
          }.bind(this), config.get('dns_resolver.reload_buffer_time'));
        }.bind(this));
      }.bind(this), reloadIn);
    }
  },

  writeNginxConfig: function(writeConfigsCallback) {
    this.nginxConfigWritesInProgress++;
    async.waterfall([
      this.fetchAllBackends.bind(this),
      this.writeNginxFrontendConfig.bind(this),
      this.writeNginxBackendsConfig.bind(this),
      this.reloadNginxOnChange.bind(this),
    ], function(error) {
      writeConfigsCallback(error);
    }.bind(this));
  },

  fetchAllBackends: function(writeNginxConfigCallback) {
    // Fetch all the valid API backends config.
    var apis = config.get('internal_apis') || [];
    apis = apis.concat(config.get('apis') || []);
    apis = cloneDeep(apis);
    apis = _.reject(apis, function(api) {
      return (!api.servers || api.servers.length === 0);
    });

    var websiteBackends = config.get('internal_website_backends') || [];
    websiteBackends = websiteBackends.concat(config.get('website_backends') || []);
    websiteBackends = cloneDeep(websiteBackends);

    writeNginxConfigCallback(null, {
      apis: apis,
      websiteBackends: websiteBackends,
    });
  },

  writeNginxFrontendConfig: function(nginxConfig, writeNginxConfigCallback) {
    logger.info('Writing nginx frontend config...');

    // Organize the known hosts (from the config file) by hostname.
    var hosts = {};
    var hostsConfig = cloneDeep(config.get('hosts'));
    hostsConfig.forEach(function(hostConfig) {
      if(!hostConfig.hostname) {
        hostConfig.hostname = '*';
      }

      if(hostConfig.default && !hostConfig.hasOwnProperty('enable_web_backend')) {
        hostConfig.enable_web_backend = true;
      }

      hosts[hostConfig.hostname] = hostConfig;
    });

    // Search each API backends config to discover new hostnames that are being
    // used and the URL prefixes in use on each hostname.
    nginxConfig.apis.forEach(function(api) {
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

    // Discover any new hostnames defined for website backends.
    nginxConfig.websiteBackends.forEach(function(websiteBackend) {
      var hostname = '*';
      if(websiteBackend.frontend_host && websiteBackend.frontend_host !== '*') {
        hostname = websiteBackend.frontend_host.split(':')[0];
      }

      if(!hosts[hostname]) {
        hosts[hostname] = {
          hostname: hostname,
        };
      }

      if(hostname !== '*') {
        hosts[hostname].website_host = websiteBackend.frontend_host;
      }

      hosts[hostname].website_protocol = websiteBackend.backend_protocol || 'http';
      hosts[hostname].website_backend = 'api_umbrella_website_' + websiteBackend._id + '_backend';
      hosts[hostname].website_backend_required_https_regex = websiteBackend.website_backend_required_https_regex || config.get('router.website_backend_required_https_regex_default');
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

      if(hosts['*'] && hosts['*'].website_backend && !hostConfig.website_backend) {
        hostConfig.website_host = hosts['*'].website_host;
        hostConfig.website_protocol = hosts['*'].website_protocol;
        hostConfig.website_backend = hosts['*'].website_backend;
      }
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
      if(hostConfig.api_url_prefixes && hostConfig.api_url_prefixes.length > 0) {
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
          writeNginxConfigCallback(error);
          return false;
        }

        logger.info('nginx frontend config written');
        this.needsNginxReload = true;
        writeNginxConfigCallback(null, _.merge(nginxConfig, { changed: true }));
      }.bind(this));
    }.bind(this);

    fs.exists(nginxPath, function(exists) {
      if(exists) {
        fs.readFile(nginxPath, function(error, data) {
          var oldContent = data.toString();
          if(oldContent === newContent) {
            logger.info('nginx frontend config already up-to-date - skipping');
            writeNginxConfigCallback(null, nginxConfig);
          } else {
            logger.info(diff.createPatch('frontend_hosts.conf', oldContent, newContent, 'old', 'new'));
            write();
          }
        });
      } else {
        write();
      }
    });
  },

  writeNginxBackendsConfig: function(nginxConfig, writeNginxConfigCallback) {
    logger.info('Writing nginx backend config...');

    nginxConfig.apis.forEach(function(api) {
      if(api.balance_algorithm === 'least_conn' || api.balance_algorithm === 'ip_hash') {
        api.defaultBalance = false;
      } else {
        api.defaultBalance = true;
      }

      if(!api.keepalive_connections) {
        api.keepalive_connections = 10;
      }

      api.servers.forEach(function(server) {
        server.nginx_servers = this.resolver.getNginxServersConfig(server.host, server.port);
      }.bind(this));
    }.bind(this));

    nginxConfig.websiteBackends.forEach(function(websiteBackend) {
      websiteBackend.nginx_servers = this.resolver.getNginxServersConfig(websiteBackend.server_host, websiteBackend.server_port);
    }.bind(this));

    var templateConfig = _.extend({}, config.getAll(), {
      apis: nginxConfig.apis,
      website_backends: nginxConfig.websiteBackends,
    });

    var newContent = this.nginxTemplate(templateConfig);

    var nginxPath = path.join(config.get('etc_dir'), 'nginx/backends.conf');

    var write = function() {
      fs.writeFile(nginxPath, newContent, function(error) {
        if(error) {
          logger.error({ err: error }, 'Error writing nginx backend config');
          writeNginxConfigCallback(error);
          return false;
        }

        logger.info('nginx backend config written');
        this.needsNginxReload = true;
        writeNginxConfigCallback(null, _.merge(nginxConfig, { changed: true }));
      }.bind(this));
    }.bind(this);

    fs.exists(nginxPath, function(exists) {
      if(exists) {
        fs.readFile(nginxPath, function(error, data) {
          var oldContent = data.toString();
          if(oldContent === newContent) {
            logger.info('nginx backend config already up-to-date - skipping');
            writeNginxConfigCallback(null, nginxConfig);
          } else {
            logger.info(diff.createPatch('backends.conf', oldContent, newContent, 'old', 'new'));
            write();
          }
        });
      } else {
        write();
      }
    });
  },

  reloadNginxOnChange: function(nginxConfig, writeNginxConfigCallback) {
    this.nginxConfigWritesInProgress--;
    if(this.needsNginxReload && this.nginxConfigWritesInProgress <= 0) {
      this.nginxConfigWritesInProgress = 0;
      this.emit('nginx');
      this.reloadNginx(function(error) {
        writeNginxConfigCallback(error);
      });
    } else if(this.needsNginxReload) {
      logger.info({ nginxConfigWritesInProgress: this.nginxConfigWritesInProgress }, 'nginx reload needed but other nginx config writes still in progress (will reload once other writes are complete)...');
    }
  },

  reloadNginx: function(callback) {
    logger.info('Reloading nginx...');

    execFile('nginx', ['-t', '-c', path.join(config.get('etc_dir'), 'nginx/router.conf')], { env: processEnv.env() }, function(error, stdout, stderr) {
      if(error) {
        logger.error({ err: error, stdout: stdout, stderr: stderr }, 'Syntax check for nginx failed');
        return callback('Syntax check for nginx failed');
      }

      supervisorSignal('router-nginx', 'SIGHUP', function(error) {
        if(error) {
          logger.error({ err: error }, 'Error reloading nginx');
          return callback('Error reloading nginx');
        }

        logger.info('nginx reload signal sent');
        callback(null);
      });
    });
  },

  handleWriteConfigs: function(error) {
    if(error) {
      logger.error({ err: error }, 'Error writing configs');
    } else {
      logger.info('Finished writing config files and reloading');
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
