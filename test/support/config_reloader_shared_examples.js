'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    config = require('../../lib/config'),
    ConfigReloader = require('../../lib/config_reloader').ConfigReloader,
    fs = require('fs'),
    path = require('path'),
    logger = require('../../lib/logger'),
    sinon = require('sinon');

sinon.stub(ConfigReloader.prototype, 'reloadNginx', function(writeConfigsCallback) {
  logger.info('Reloading nginx (stub)...');

  if(writeConfigsCallback) {
    writeConfigsCallback(null);
  }
});

_.merge(global.shared, {
  runConfigReloader: function(configOverrides) {
    if(configOverrides) {
      beforeEach(function(done) {
        Factory.create('config_version', { config: configOverrides }, function() {
          done();
        }.bind(this));
      });
    }

    beforeEach(function(done) {
      config.reset();

      this.configReloader = new ConfigReloader(function() {
        async.parallel([
          function(callback) {
            var filePath = path.join(config.configDir, 'nginx.conf');
            fs.readFile(filePath, function(error, data) {
              this.nginxConfigContents = data.toString();
              callback(error);
            }.bind(this));
          }.bind(this),
          function(callback) {
            var filePath = config.runtimePath;
            fs.readFile(filePath, function(error, data) {
              this.gatekeeperConfigContents = data.toString();
              callback(error);
            }.bind(this));
          }.bind(this),
        ], done);
      }.bind(this));
    });

    afterEach(function(done) {
      this.configReloader.close(done);
    });
  },
});
