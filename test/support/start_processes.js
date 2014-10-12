'use strict';

require('../test_helper');

var path = require('path'),
    router = require('../../lib/router');

before(function startProcesses(done) {
  this.timeout(180000);

  var options = {
    config: [path.resolve(__dirname, '../config/test.yml')],
  };

  this.router = router.run(options, done);
});
