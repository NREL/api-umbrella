'use strict';

require('../test_helper');

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    async = require('async'),
    fs = require('fs'),
    path = require('path');

// FIXME: Setting the global config that isn't really correct (this simple one
// isn't merged with the defaults). Must be done before the config reloader
// worker class is included. This whole config reloader test file really needs
// to be redone in a more "integrationy" way, or done differently. This was
// pulled from the test suite from when this lived in the gatekeeper project,
// but doesn't really jive with how the router tests are run.
apiUmbrellaConfig.setGlobal(path.resolve(__dirname, '../config/test.yml'));
var config = apiUmbrellaConfig.global();
var ConfigReloaderWorker = require('../../lib/config_reloader/worker').Worker;

_.merge(global.shared, {
  runConfigReloader: function() {
    beforeEach(function setupConfigReloader(done) {
      this.timeout(10000);

      this.configReloader = new ConfigReloaderWorker();
      this.configReloader.on('ready', function() {
        async.parallel([
          function(callback) {
            var filePath = path.join(config.get('etc_dir'), 'nginx/backends.conf');
            fs.readFile(filePath, function(error, data) {
              this.nginxConfigContents = data.toString();
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
