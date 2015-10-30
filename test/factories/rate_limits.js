'use strict';

require('../test_helper');
require('../support/models/rate_limit');

var Factory = require('factory-lady'),
    mongoose = require('mongoose');

var RateLimit = mongoose.testConnection.model('RateLimit');

// Override the save method to add an "updated_at" timestamp using MongoDB's
// $currentDate and upsert features (this ensures the timestamps are set on the
// server and therefore not subject to clock drift on the clients--this is
// important in this case, since we use updated_at to detect when changes have
// been made to the user collection).
RateLimit.prototype.save = function(callback) {
  var data = this.toObject();
  delete data._id;
  var upsertData = {
    $set: data,
    $currentDate: {
      ts: { $type: 'timestamp' },
    },
  };

  RateLimit.update({ _id: this._id }, upsertData, { upsert: true }, callback);
};

Factory.define('rate_limit', RateLimit, {
});
