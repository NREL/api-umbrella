'use strict';

require('../test_helper');

var config = require('./config'),
    path = require('path'),
    rimraf = require('rimraf');

// Wipe all the beanstalkd data by deleting the data directory (beanstalk
// doesn't have a super-easy way to drop everything without peeking at each
// record).
before(function deleteBeanstalk(done) {
  rimraf(path.join(config.get('db_dir'), 'beanstalkd'), done);
});
