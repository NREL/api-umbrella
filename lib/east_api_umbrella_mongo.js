'use strict';

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    EastMongoAdapter = require('east-mongo');

var configPath = process.env.API_UMBRELLA_CONFIG || '/opt/api-umbrella/var/run/runtime_config.yml';
apiUmbrellaConfig.setGlobal(configPath);
var config = apiUmbrellaConfig.global();

var Adapter = function(params) {
  params = params || {};

  if(!params.url) {
    params.url = config.get('mongodb.url');
  }

  EastMongoAdapter.call(this, params);
};

Adapter.prototype = _.create(EastMongoAdapter.prototype, {
  _super: EastMongoAdapter.prototype,
  constructor: Adapter,
});

module.exports = Adapter;
