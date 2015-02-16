'use strict';

require('../test_helper');

var apiUmbrellaConfig = require('api-umbrella-config'),
    async = require('async'),
    fs = require('fs'),
    fsExtra = require('fs-extra'),
    mkdirp = require('mkdirp'),
    path = require('path'),
    request = require('request'),
    spawn = require('child_process').spawn;

var config = apiUmbrellaConfig.load(path.resolve(__dirname, '../config/test.yml'));

before(function clearTestEnvDns() {
  // This included file must exist before unbound can start.
  var configPath = path.join(config.get('etc_dir'), 'test_env/unbound/active_test.conf');
  mkdirp.sync(path.dirname(configPath));
  fs.writeFileSync(configPath, '');
});

global.nginxPidFile = path.resolve(__dirname, '../tmp/nginx.pid');
before(function nginxStart(done) {
  this.timeout(30000);

  process.stdout.write('Waiting for api-umbrella to start...');
  var startWaitLog = setInterval(function() {
    process.stdout.write('.');
  }, 2000);

  // Spin up the nginx process.
  var binPath = path.resolve(__dirname, '../../bin/api-umbrella');
  var configPath = path.resolve(__dirname, '../config/test.yml');
  global.apiUmbrellaServer = spawn(binPath, ['--config', configPath, 'run'], { stdio: 'inherit' });

  // Wait until we're able to establish a connection before moving on.
  var healthy = false;
  async.until(function() {
    return healthy;
  }, function(callback) {
    request.get('http://127.0.0.1:9333/api-umbrella/v1/health', function(error, response, body) {
      if(!error && response && response.statusCode === 200) {
        var data = JSON.parse(body);
        if(data['status'] === 'green') {
          healthy = true;
          console.info('\n');
          clearInterval(startWaitLog);
          return callback();
        }
      }

      setTimeout(callback, 100);
    });
  }, done);
});

before(function copyRuntimeConfig() {
  var runtimeConfigPath = '/tmp/api-umbrella-test/var/run/runtime_config.yml';
  fsExtra.copySync(runtimeConfigPath, runtimeConfigPath + '.orig');
});
