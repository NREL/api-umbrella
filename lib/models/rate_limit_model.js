'use strict';

var mongoose = require('mongoose');

module.exports = function(options) {
  var expireAfter = options.duration + options.accuracy + 1000;
  var prefix = options.limit_by + ':' + options.duration;

  var existingModelNames = mongoose.modelNames();
  var collection = 'rate_limits_' + prefix.replace(/:/, '_');

  var model;
  if(existingModelNames.indexOf(collection) === -1) {
    model = mongoose.model(collection, new mongoose.Schema({
      _id: String,
      time: {
        type: Date,
        expires: expireAfter / 1000,
      },
      count: Number,
      updated_at: {
        type: Date,
        index: true,
      },
    }, { collection: collection }));
  } else {
    model = mongoose.model(collection);
  }

  return model;
};
