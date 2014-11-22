'use strict';

var _ = require('lodash'),
    async = require('async'),
    cloneDeep = require('clone'),
    config = require('api-umbrella-config').global(),
    events = require('events'),
    execFile = require('child_process').execFile,
    fs = require('fs'),
    handlebars = require('handlebars'),
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

    this.handleStartup();
  },

  handleStartup: function(error) {
    logger.info('Handle startup');
    if(error) {
      logger.error({ err: error }, 'Config reloader startup error');
      process.exit(1);
      return false;
    }

    this.writeConfigs();
    config.on('change', this.writeConfigs.bind(this));

    // FIXME: Something to keep this worker alive to detect config changes.
    // Should revisit to see if this should be integrated into
    // api-umbrella-config.
    setInterval(function() {}, 60000);
  },

  writeConfigs: function() {
    logger.info('Write configs');
    // Write nginx config's first.
    async.series([
      this.writeNginxConfig.bind(this),
    ], this.handleWriteConfigs.bind(this));
  },

  writeNginxConfig: function(writeConfigsCallback) {
    logger.info('Writing nginx config...');

    logger.info({ apis: config.get('apis') }, 'APIs');

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

    execFile('nginx', ['-t', '-c', path.join(config.get('etc_dir'), 'nginx/router.conf')], processEnv.env(), function(error, stdout, stderr) {
      if(error) {
        logger.error({ err: error, stdout: stdout, stderr: stderr }, 'Syntax check for nginx failed');
        return writeConfigsCallback('Syntax check for nginx failed');
      }

      logger.info('Syntax check for nginx passes');

      execFile('supervisorctl', ['-c', processEnv.supervisordConfigPath(), 'kill', 'HUP', 'router-nginx'], processEnv.env(), function(error, stdout, stderr) {
        if(error) {
          logger.error({ err: error, stdout: stdout, stderr: stderr }, 'Error reloading nginx');
          return writeConfigsCallback('Error reloading nginx');
        }

        logger.info('Nginx reloaded... ' + stdout + ' ' + stderr);
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

    if(callback) {
      callback(null);
    }
  },
});
