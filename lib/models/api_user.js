'use strict';

var apiUserSchema = require('./api_user_schema'),
    mongoose = require('mongoose');

module.exports = mongoose.model('ApiUser', apiUserSchema());
