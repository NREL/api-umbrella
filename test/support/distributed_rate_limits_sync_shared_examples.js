'use strict';

require('../test_helper');

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    distributedRateLimitSync = require('../../lib/distributed_rate_limits_sync'),
    fs = require('fs'),
    path = require('path'),
    yaml = require('js-yaml');

_.merge(global.shared, {
  runDistributedRateLimitsSync: function(configOverrides) {
    beforeEach(function startConfigLoader(done) {
      this.timeout(5000);
      var overridesPath = path.resolve(__dirname, '../config/overrides.yml');
      fs.writeFileSync(overridesPath, yaml.dump(configOverrides || {}));

      apiUmbrellaConfig.loader({
        paths: [
          path.resolve(__dirname, '../../config/default.yml'),
          path.resolve(__dirname, '../config/test.yml'),
        ],
        overrides: configOverrides,
      }, function(error, loader) {
        this.loader = loader;
        done(error);
      }.bind(this));
    });

    beforeEach(function startSync(done) {
      this.sync = distributedRateLimitSync.start({
        config: this.loader.runtimeFile,
      }, done);
    });

    afterEach(function stopConfigLoader(done) {
      if(this.loader) {
        this.loader.close(done);
      }
    });

    afterEach(function stopSync(done) {
      if(this.sync) {
        this.sync.close(done);
      }
    });
  },
});
