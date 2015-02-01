'use strict';

require('../test_helper');

var async = require('async'),
    request = require('request');

describe('proxy concurrency', function() {
  shared.runServer();

  it('proxies multiple concurrent requests properly', function(done) {
    // Fire off 20 concurrent requests and ensure that all the streamed
    // responses are proxied properly (in other words, nothing in the proxy is
    // mishandling or mixing up chunks). Just a sanity check given the async
    // nature of all this.
    var urlBase = 'http://localhost:9333/echo_delayed_chunked?api_key=' + this.apiKey;
    async.times(20, function(index, next) {
      var randomInput = Math.random().toString();
      var url =  urlBase + '&input=' + randomInput;

      request.get(url, {
        agentOptions: {
          maxSockets: 500,
        },
      }, function(error, response, body) {
        next(null, {
          input: randomInput,
          output: body,
        });
      });
    }, function(error, requests) {
      for(var i = 0; i < requests.length; i++) {
        var request = requests[i];
        request.output.should.eql(request.input);
      }

      done();
    });
  });
});

