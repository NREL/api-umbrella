'use strict';

var mongoose = global.mongoose || require('mongoose');

module.exports = mongoose.model('LogCityLocation', new mongoose.Schema({
  _id: String,
  country: String,
  region: String,
  city: String,
  location: mongoose.Schema.Types.Mixed,
  updated_at: Date,
}, { collection: 'log_city_locations' }));
