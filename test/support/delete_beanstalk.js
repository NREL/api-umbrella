'use strict';

require('../test_helper');

var apiUmbrellaConfig = require('api-umbrella-config'),
    path = require('path'),
    rimraf = require('rimraf');

var config = apiUmbrellaConfig.load(path.resolve(__dirname, '../config/test.yml'));

// Wipe all the beanstalkd data by deleting the data directory (beanstalk
// doesn't have a super-easy way to drop everything without peeking at each
// record).
before(function deleteBeanstalk(done) {
  rimraf(path.join(config.get('db_dir'), 'beanstalkd'), done);
});
