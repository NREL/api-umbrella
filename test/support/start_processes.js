'use strict';

require('../test_helper');

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
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
  var configPath = path.join(config.get('etc_dir'), 'test-env/unbound/active_test.conf');
  mkdirp.sync(path.dirname(configPath));
  fs.writeFileSync(configPath, '');
});

before(function stubDummyStaticSite() {
  mkdirp.sync(path.join(config.get('static_site.build_dir'), 'signup'));
  fs.writeFileSync(path.join(config.get('static_site.build_dir'), 'index.html'), 'Your API Site Name');
  fs.writeFileSync(path.join(config.get('static_site.build_dir'), 'signup/index.html'), 'API Key Signup');
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

  var testConfigPath = path.resolve(__dirname, '../config/test.yml');
  var overridesConfigPath = path.resolve(__dirname, '../config/.overrides.yml');
  fsExtra.copySync(testConfigPath, overridesConfigPath);

  // Spin up the api-umbrella processes.
  var binPath = path.resolve(__dirname, '../../bin/api-umbrella');
  global.apiUmbrellaServer = spawn(binPath, ['run'], {
    stdio: 'inherit',
    env: _.merge({}, process.env, {
      'API_UMBRELLA_ROOT': process.env.API_UMBRELLA_ROOT,
      'API_UMBRELLA_CONFIG': overridesConfigPath,
    }),
  });

  global.apiUmbrellaServer.on('close', function() {
    if(startWaitLog) {
      console.error('Error: api-umbrella failed to start');
      process.exit(1);
    }
  });

  // Wait until we're able to establish a connection before moving on.
  var healthy = false;
  async.until(function() {
    return healthy && global.mongoOrchestrationReady;
  }, function(callback) {
    request.get('http://127.0.0.1:9080/api-umbrella/v1/health', function(error, response, body) {
      if(!error && response && response.statusCode === 200) {
        var data = JSON.parse(body);
        if(data['status'] === 'green') {
          healthy = true;
          return callback();
        }
      }

      setTimeout(callback, 100);
    });
  }, function(error) {
    console.info('\n');
    clearInterval(startWaitLog);
    startWaitLog = null;
    done(error);
  });
});
