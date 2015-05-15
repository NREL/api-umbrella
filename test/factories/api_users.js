'use strict';

require('../test_helper');
require('../../lib/models/api_user');

var Factory = require('factory-lady'),
    uuid = require('node-uuid'),
    mongoose = require('mongoose');

function generateId(callback) {
  callback(uuid.v4());
}

var userCounter = 1;
function generateApiKey(callback) {
  callback('TESTING_KEY_' + ('00000' + userCounter++).slice(-5));
}

var ApiUser = mongoose.testConnection.model('ApiUser');

// Override the save method to add an "updated_at" timestamp using MongoDB's
// $currentDate and upsert features (this ensures the timestamps are set on the
// server and therefore not subject to clock drift on the clients--this is
// important in this case, since we use updated_at to detect when changes have
// been made to the user collection).
ApiUser.prototype.save = function(callback) {
  var data = this.toObject();
  delete data._id;
  var upsertData = {
    $set: data,
    $currentDate: {
      updated_at: { $type: 'date' },
    },
  };

  ApiUser.update({ _id: this._id }, upsertData, { upsert: true }, callback);
};

Factory.define('api_user', ApiUser, {
  _id: generateId,
  api_key: generateApiKey,
  first_name: 'Testing',
  last_name: 'Key',
  email: 'testing_key@nrel.gov',
  website: 'http://nrel.gov/',
  registration_source: 'web',
  roles: [],
});
