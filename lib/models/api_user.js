'use strict';

var ApiUserSchema = require('./api_user_schema'),
    mongoose = require('mongoose');

module.exports = mongoose.model('ApiUser', ApiUserSchema);
