'use strict';

require('../test_helper');

var path = require('path'),
    router = require('../../lib/router');

before(function(done) {
  this.timeout(20000);

  var options = {
    config: [path.resolve(__dirname, '../config/test.yml')],
  };

  this.router = router.run(options, done);
});

after(function(done) {
  this.router.stop(done);
});
