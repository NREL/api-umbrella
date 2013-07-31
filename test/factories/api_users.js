'use strict';

require('../test_helper');

var ApiUser = mongoose.model('api_users', {
  api_key: {
    type: String,
    index: { unique: true },
  },
  first_name: String,
  last_name: String,
  email: String,
  website: String,
  roles: [String],
});

var userCounter = 1;
function generateApiKey(callback) {
  callback('TESTING_KEY_' + ('00000' + userCounter++).slice(-5));
}

Factory.define('api_user', ApiUser, {
  api_key: generateApiKey,
  first_name: 'Testing',
  last_name: 'Key',
  email: 'testing_key@nrel.gov',
  website: 'http://nrel.gov/',
  roles: [],
});
