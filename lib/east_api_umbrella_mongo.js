'use strict';

var _ = require('lodash'),
    config = require('api-umbrella-config').global(),
    EastMongoAdapter = require('east-mongo');

var Adapter = function(params) {
  params = params || {};

  if(!params.url) {
    params.url = config.get('mongodb.url');
  }

  return new EastMongoAdapter(params);
};

Adapter.prototype = _.create(EastMongoAdapter.prototype, {
  constructor: Adapter,
});

module.exports = Adapter;
