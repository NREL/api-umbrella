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
    beforeEach(function(done) {
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

    beforeEach(function(done) {
      this.sync = distributedRateLimitSync.start({
        config: this.loader.runtimeFile,
      }, done);
    });

    afterEach(function(done) {
      this.loader.close(done);
    });

    afterEach(function(done) {
      this.sync.close(done);
    });
  },
});
