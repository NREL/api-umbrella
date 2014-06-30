'use strict';

require('../test_helper');

var Factory = require('factory-lady'),
    mongoose = require('mongoose'),
    uuid = require('node-uuid');

require('api-umbrella-gatekeeper').models(mongoose);

function generateId(callback) {
  callback(uuid.v4());
}

var userCounter = 1;
function generateApiKey(callback) {
  callback('TESTING_KEY_' + ('00000' + userCounter++).slice(-5));
}

Factory.define('api_user', mongoose.testConnection.model('ApiUser'), {
  _id: generateId,
  api_key: generateApiKey,
  first_name: 'Testing',
  last_name: 'Key',
  email: 'testing_key@nrel.gov',
  website: 'http://nrel.gov/',
  registration_source: 'web',
  roles: [],
});
