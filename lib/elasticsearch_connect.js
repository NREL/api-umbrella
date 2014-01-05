'use strict';

var _ = require('lodash'),
    async = require('async'),
    config = require('./config'),
    elasticsearch = require('elasticsearch'),
    fs = require('fs'),
    logger = require('./logger'),
    moment = require('moment'),
    path = require('path');

var ElasticSearchConnect = function() {
  this.initialize.apply(this, arguments);
};

_.extend(ElasticSearchConnect.prototype, {
  initialize: function(callback) {
    this.callback = callback;
    this.client = new elasticsearch.Client(config.get('elasticsearch'));

    async.series([
      this.setupTemplates.bind(this),
      this.setupDefaultAliases.bind(this),
    ], this.finishConnect.bind(this));
  },

  setupTemplates: function(asyncReadyCallback) {
    // First ensure the legacy, unversioned template is deleted so multiple
    // matches don't occur. Going forward our templates contain version
    // numbers.
    this.client.indices.deleteTemplate({
      name: 'api-umbrella-log-template',
    }, function() {
      var templatesPath = path.join(process.cwd(), 'config', 'elasticsearch_templates.json');
      fs.readFile(templatesPath, this.handleTemplates.bind(this, asyncReadyCallback));
    }.bind(this));
  },

  handleTemplates: function(asyncReadyCallback, error, templates) {
    this.templates = JSON.parse(templates.toString());
    async.each(this.templates, this.uploadTemplate.bind(this), asyncReadyCallback);
  },

  uploadTemplate: function(template, callback) {
    this.client.indices.putTemplate({
      name: template.id,
      body: template.template,
    }, function(error) {
      if(error) {
        logger.error('Template error: ', error);
      }

      callback(null);
    });
  },

  setupDefaultAliases: function(asyncReadyCallback) {
    var env = config.environment;
    var today = moment().utc().format('YYYY-MM');
    var tomorrow = moment().add('days', 1).utc().format('YYYY-MM');

    var aliases = _.uniq([
      {
        name: 'api-umbrella-logs-' + env + '-' + today,
        index: 'api-umbrella-logs-' + config.get('log_template_version') + '-' + env + '-' + today,
      },
      {
        name: 'api-umbrella-logs-write-' + env + '-' + today,
        index: 'api-umbrella-logs-' + config.get('log_template_version') + '-' + env + '-' + today,
      },
      {
        name: 'api-umbrella-logs-' + env + '-' + tomorrow,
        index: 'api-umbrella-logs-' + config.get('log_template_version') + '-' + env + '-' + tomorrow,
      },
      {
        name: 'api-umbrella-logs-write-' + env + '-' + tomorrow,
        index: 'api-umbrella-logs-' + config.get('log_template_version') + '-' + env + '-' + tomorrow,
      },
    ], 'name');

    async.each(aliases, this.createAlias.bind(this), function() {
      // Since we have dynamic, date-based indexes, we need to ensure that the
      // aliases for the current time are kept up to date. So keep re-running
      // the setup alias function to ensure that the aliases already exist
      // before the next month hits (otherwise, elasticsearch would end up
      // creating an actual index in place of the alias's name).
      setTimeout(this.setupDefaultAliases.bind(this), 3600000);

      if(asyncReadyCallback) {
        asyncReadyCallback(null);
      }
    }.bind(this));
  },

  createAlias: function(alias, callback) {
    this.client.indices.existsAlias({
      name: alias.name,
    }, function(error, exists) {
      if(exists) {
        callback(error);
      } else {
        this.client.indices.create({
          index: alias.index,
        }, function() {
          this.client.indices.putAlias(alias, callback);
        }.bind(this));
      }
    }.bind(this));
  },

  finishConnect: function(error) {
    this.callback(error, this.client);
  },
});


module.exports = function(callback) {
  new ElasticSearchConnect(callback);
};
