'use strict';

require('../test_helper');

var _ = require('lodash'),
    Factory = require('factory-lady'),
    mongoose = require('mongoose'),
    request = require('request');

_.merge(global.shared, {
  chunkedRequestDetails: function(options, callback) {
    request(options).on('response', function(response) {
      var bodyString = '';
      var chunks = [];
      var stringChunks = [];
      var chunkTimeGaps = [];
      var lastChunkTime;

      response.on('data', function(chunk) {
        bodyString += chunk.toString();
        chunks.push(chunk);
        stringChunks.push(chunk.toString());

        if(lastChunkTime) {
          var gap = Date.now() - lastChunkTime;
          chunkTimeGaps.push(gap);
        }

        lastChunkTime = Date.now();
      });

      response.on('end', function() {
        callback(response, {
          bodyString: bodyString,
          chunks: chunks,
          stringChunks: stringChunks,
          chunkTimeGaps: chunkTimeGaps,
        });
      });
    });
  },

  publishDbConfig: function(config, callback) {
    mongoose.testConnection.model('RouterConfigVersion').remove({}, function(error) {
      should.not.exist(error);

      Factory.create('config_version', {
        config: config,
      }, function() {
        // Wait a bit for the Mongo config polling to pickup the change and for
        // nginx to reload.
        setTimeout(callback, 2000);
      });
    });
  },

  removeDbConfig: function(callback) {
    // Wipe the mongo-based config after finishing so that the file-based
    // YAML config takes precedence again (api-umbrella-config overwrites
    // the apis array from the mongo config if present, which I'm not
    // sure this is actually what we want, but since we don't actually
    // need merging behavior right now, we'll just wipe this).
    mongoose.testConnection.model('RouterConfigVersion').remove({}, function(error) {
      should.not.exist(error);

      // Wait a bit for the Mongo config polling to pickup the change and for
      // nginx to reload.
      setTimeout(callback, 2000);
    });
  }
});
