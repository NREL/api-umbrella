'use strict';

require('../test_helper');

var Factory = require('factory-lady'),
    mongoose = require('mongoose'),
    uuid = require('node-uuid');

require('../../lib/models/admin');

function generateId(callback) {
  callback(uuid.v4());
}

Factory.define('admin', mongoose.testConnection.model('Admin'), {
  _id: generateId,
});
