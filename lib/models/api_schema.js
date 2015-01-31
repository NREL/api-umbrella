'use strict';

module.exports = function(mongoose) {
  mongoose = mongoose || require('mongoose');

  return new mongoose.Schema({
    _id: mongoose.Schema.Types.Mixed,
  }, {
    collection: 'apis',

    // Make this model schema-less so we can insert whatever we want.
    //
    // This model is normally interacted with via the Rails app, where we do
    // define all the schema. This model is defined here just for seeding data,
    // which we'll assume is correct and doesn't need all the schema
    // validations. But if we start to do more with this model on this side, we
    // should revisit this.
    strict: false,
  });
};
