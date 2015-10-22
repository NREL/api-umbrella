'use strict';

require('../test_helper');

var Factory = require('factory-lady'),
    uuid = require('node-uuid'),
    mongoose = require('mongoose');

function generateId(callback) {
  callback(uuid.v4());
}

var counter = 1;
function generateToken(callback) {
  callback('ADMIN_TOKEN_' + ('00000' + counter++).slice(-5));
}

function generateEmail(callback) {
  callback('admin' + ('00000' + counter++).slice(-5) + '@example.com');
}

mongoose.model('Admin', new mongoose.Schema({
  _id: mongoose.Schema.Types.Mixed,
  username: String,
  superuser: Boolean,
  authentication_token: String,
}, { collection: 'admins', minimize: false }));

Factory.define('admin', mongoose.testConnection.model('Admin'), {
  _id: generateId,
  username: generateEmail,
  superuser: true,
  authentication_token: generateToken,
});
