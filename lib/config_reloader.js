'use strict';

var _ = require('lodash'),
    async = require('async'),
    cloneDeep = require('clone'),
    config = require('api-umbrella-config'),
    DnsResolver = require('./config_reloader/dns_resolver').DnsResolver,
    events = require('events'),
    exec = require('child_process').exec,
    fs = require('fs'),
    handlebars = require('handlebars'),
    path = require('path'),
    traverse = require('traverse'),
    util = require('util');

process.on('uncaughtException', function(err) {
  console.log(err.stack);
  throw err;
});

var ConfigReloader = function() {
  this.initialize.apply(this, arguments);
};

util.inherits(ConfigReloader, events.EventEmitter);
_.extend(ConfigReloader.prototype, {
  initialize: function(options) {
    this.options = options;

    var templatePath = path.resolve(__dirname, '../config/nginx/api_backends.conf.hbs');
    var templateContent = fs.readFileSync(templatePath);
    this.nginxTemplate = handlebars.compile(templateContent.toString());

    async.parallel([
      this.setupDnsResolver.bind(this),
    ], this.handleStartup.bind(this));
  },

  setupDnsResolver: function(asyncReadyCallback) {
    this.resolver = new DnsResolver(asyncReadyCallback);
  },

  handleStartup: function(error) {
    if(error) {
      console.error('Config reloader startup error: ', error);
      process.exit(1);
      return false;
    }

    this.writeConfigs();
  },

  writeConfigs: function() {
    // Write nginx config's first.
    async.series([
      this.resolveHosts.bind(this),
      this.writeNginxConfig.bind(this),
    ], this.handleWriteConfigs.bind(this));
  },

  resolveHosts: function(writeConfigsCallback) {
    console.info('Resolving all hosts..');
    this.resolver.resolveAllHosts(this.handleResolveHosts.bind(this, writeConfigsCallback));
  },

  handleResolveHosts: function(writeConfigsCallback, error) {
    console.info('Handle resolving all hosts..');
    writeConfigsCallback(error);

    // After resolving all the hosts, listen for one-off DNS changes for hosts
    // and re-write the nginx config file as needed.
    this.resolver.on('hostChanged', function() {
      if(this.hostChangedRestart) {
        console.info('IP changes - restart already scheduled');
      } else {
        var restartIn = 0;

        // Prevent a problematic host from constantly restarting the server in
        // quick succession.
        if(this.restartedRecently) {
          restartIn = 15 * 60 * 1000; // 15 minutes
        }

        console.info('IP changes - scheduling restart in ' + restartIn + 'ms');
        this.hostChangedRestart = setTimeout(function() {
          console.info('IP changes - restarting now');
          this.writeNginxConfig.bind(this);
          this.hostChangedRestart = null;

          this.restartedRecently = true;
          setTimeout(function() {
            this.restartedRecently = false;
          }.bind(this), 15 * 60 * 1000);
        }.bind(this), restartIn);
      }
    }.bind(this));
  },

  writeNginxConfig: function(writeConfigsCallback) {
    console.info('Writing nginx config...');

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

    var nginxPath = path.resolve(__dirname, '../config/nginx/api_backends.conf');

    var write = function() {
      fs.writeFile(nginxPath, newContent, function(error) {
        if(error) {
          console.error('Error writing nginx config: ', error);
          if(writeConfigsCallback) {
            writeConfigsCallback(error);
          }

          return false;
        }

        console.info('Nginx config written...');

        this.emit('nginx');

        this.reloadNginx(writeConfigsCallback);
      }.bind(this));
    }.bind(this);

    fs.exists(nginxPath, function(exists) {
      if(exists) {
        fs.readFile(nginxPath, function(error, data) {
          var oldContent = data.toString();
          if(oldContent === newContent) {
            console.info('Nginx config already up-to-date - skipping...');

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
    console.info('Reloading nginx...');
    exec('sudo /etc/init.d/nginx configtest && sudo /etc/init.d/nginx reload', function(error, stdout, stderr) {
      if(error) {
        console.error('Error reloading nginx: ', error, stderr, stdout);
      }

      console.info('Nginx reloaded... ', stdout + ' ' + stderr);

      if(writeConfigsCallback) {
        writeConfigsCallback(null);
      }
    });
  },

  handleWriteConfigs: function(error) {
    if(error) {
      console.error('Error writing configs: ', error);
    } else {
      console.info('Config files written...');
      this.emit('reloaded');
    }
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
