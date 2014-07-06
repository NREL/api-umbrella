'use strict';

require('../test_helper');

var _ = require('lodash'),
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
});
