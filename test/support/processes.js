'use strict';

require('../test_helper');

var path = require('path'),
    router = require('../../lib/router');

before(function startProcesses(done) {
  this.timeout(120000);

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
