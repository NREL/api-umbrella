'use strict';

var apiSchema = require('./api_schema'),
    mongoose = require('mongoose');

module.exports = mongoose.model('Api', apiSchema());
