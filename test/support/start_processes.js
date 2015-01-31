'use strict';

require('../test_helper');

var apiUmbrellaConfig = require('api-umbrella-config'),
    fs = require('fs'),
    mkdirp = require('mkdirp'),
    path = require('path'),
    router = require('../../lib/router');

var config = apiUmbrellaConfig.load(path.resolve(__dirname, '../config/test.yml'));

before(function clearTestEnvDns() {
  // This included file must exist before unbound can start.
  var configPath = path.join(config.get('etc_dir'), 'test_env/unbound/active_test.conf');
  mkdirp.sync(path.dirname(configPath));
  fs.writeFileSync(configPath, '');
});

before(function startProcesses(done) {
  this.timeout(180000);

  var options = {
    config: [
      path.resolve(__dirname, '../config/test.yml'),
      '/tmp/api-umbrella-test.yml',
    ],
  };

  this.router = router.run(options, done);
});
