'use strict';

require('../test_helper');

var exec = require('child_process').exec,
    path = require('path'),
    router = require('../../lib/router');

before(function clearCache(done) {
  exec('traffic_server -Cclear', {
    env: {
      'PATH': [
        '/home/vagrant/ats/bin',
        '/opt/api-umbrella/embedded/bin',
        '/usr/local/sbin',
        '/usr/local/bin',
        '/usr/sbin',
        '/usr/bin',
        '/sbin',
        '/bin',
      ].join(':'),
    }
  }, done);
});

before(function startProcesses(done) {
  this.timeout(60000);

  var options = {
    config: [path.resolve(__dirname, '../config/test.yml')],
  };

  this.router = router.run(options, done);
});

after(function stopProcesses(done) {
  if(this.router) {
    this.router.stop(done);
  }
});
