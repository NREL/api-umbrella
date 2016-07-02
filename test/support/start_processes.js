'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    config = require('./config'),
    execFile = require('child_process').execFile,
    fs = require('fs'),
    mkdirp = require('mkdirp'),
    path = require('path'),
    request = require('request'),
    spawn = require('child_process').spawn;

before(function clearTestEnvDns() {
  // This included file must exist before unbound can start.
  var configPath = path.join(config.get('root_dir'), 'etc/test-env/unbound/active_test.conf');
  mkdirp.sync(path.dirname(configPath));
  fs.writeFileSync(configPath, '');
});

// Trigger the mongo-orchestration setup to configure our replicaset.
//
// Note that this is a bit funny, since mongo-orchestration doesn't actually
// get started until we startup api-umbrella and all of the other server
// processes in the next apiUmbrellaStart method (we start it in there mainly
// since that's the easiest place to start a process that should start/stop
// with everything else as part of the test run).
before(function mongoOrchestrationSetup() {
  // Since we're doing this setup asyncronsouly so we can continue onto the
  // next before apiUmbrellaStart method call, setup our own timeout to bail on
  // testing if this doesn't respond as expected.
  var timeout = setTimeout(function() {
    console.error('Unable to establish connection to mongo-orchestration');
    return process.exit(1);
  }.bind(this), 20000);
  timeout.unref();

  // First wait for mongo-orchestration to get started.
  var connected = false;
  var attemptDelay = 250;
  async.until(function() {
    return connected;
  }, function(untilCallback) {
    request({ url: 'http://127.0.0.1:13089/', timeout: 1500 }, function(error) {
      if(!error) {
        connected = true;
        untilCallback();
      } else {
        setTimeout(untilCallback, attemptDelay);
      }
    });
  }, function() {
    clearTimeout(timeout);

    // Once started, send our config file to configure the replica set for
    // testing.
    request.put({
      url: 'http://127.0.0.1:13089/v1/replica_sets/test-cluster',
      body: fs.readFileSync(path.resolve(__dirname, '../config/mongo-orchestration.json')).toString(),
      timeout: 120000,
    }, function(error) {
      global.mongoOrchestrationReady = true;

      if(error && !global.apiUmbrellaStopping) {
        console.error('mongo-orchestration failed: ', error);
        return process.exit(1);
      }
    });
  });
});

before(function apiUmbrellaStart(done) {
  this.timeout(100000);

  process.stdout.write('Waiting for api-umbrella to start...');
  var startWaitLog = setInterval(function() {
    process.stdout.write('.');
  }, 2000);

  var testConfigPath = process.env['API_UMBRELLA_CONFIG'] || path.resolve(__dirname, '../config/test.yml');
  var overridesConfigPath = path.resolve(__dirname, '../config/.overrides.yml');
  fs.writeFileSync(overridesConfigPath, '');
  var configPath = testConfigPath + ':' + overridesConfigPath;

  // Spin up the api-umbrella processes.
  var binPath = path.resolve(__dirname, '../../bin/api-umbrella');
  process.env.API_UMBRELLA_EMBEDDED_ROOT = path.resolve(__dirname, '../../build/work/stage/opt/api-umbrella/embedded');
  global.apiUmbrellaServer = spawn(binPath, ['run'], {
    stdio: 'inherit',
    env: _.merge({}, process.env, {
      'API_UMBRELLA_EMBEDDED_ROOT': process.env.API_UMBRELLA_EMBEDDED_ROOT,
      'API_UMBRELLA_CONFIG': configPath,
    }),
  });

  global.apiUmbrellaServer.on('close', function() {
    if(startWaitLog) {
      console.error('Error: api-umbrella failed to start');
      process.exit(1);
    }
  });

  // Wait until API Umbrella is fully ready and the mongo-orchestration has
  // completed.
  var healthy = false;
  async.until(function() {
    return healthy && global.mongoOrchestrationReady;
  }, function(callback) {
    execFile(binPath, ['health', '--wait-for-status', 'green', '--wait-timeout', '90'], {
      env: _.merge({}, process.env, {
        'API_UMBRELLA_EMBEDDED_ROOT': process.env.API_UMBRELLA_EMBEDDED_ROOT,
        'API_UMBRELLA_CONFIG': configPath,
      }),
    }, function(error, stdout, stderr) {
      if(error) {
        error = 'Error waiting for api umbrella to start: ' + error + ' (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')';
      } else {
        healthy = true;
      }

      callback(error);
    });
  }, function(error) {
    console.info('\n');
    clearInterval(startWaitLog);
    startWaitLog = null;
    done(error);
  });
});
