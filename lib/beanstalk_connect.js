'use strict';

var logger = require('./logger'),
    fivebeans = require('fivebeans');

module.exports = function(callback) {
  var config = require('api-umbrella-config').global();

  var connected = false;
  var client = new fivebeans.client(config.get('beanstalkd.host'), config.get('beanstalkd.port'));

  client.on('error', function(error) {
    logger.error({ err: error }, 'beanstalk error');

    if(!connected) {
      // If an error occurs during initial startup, call the callback with the
      // error.
      callback(error);
    }
  });

  client.on('connect', function() {
    client.watch('logs', function(error) {
      if(error) {
        logger.error({ err: error}, 'beanstalk use "logs" tube error');
      }

      // For initial startup connections, call the callback. For reconnections
      // emit a "reconnect" event that can be listened for.
      if(connected) {
        logger.info('beanstalk reconnected');
        client.emit('reconnect');
      } else {
        connected = true;
        callback(error, client);
      }
    });
  });

  client.on('close', function(error) {
    // If an unexpected close event happens (not part of a proper shutdown),
    // then try to reconnect the client.
    if(!client.exitingProcess) {
      logger.error({ err: error }, 'beanstalk close');
      setTimeout(function() {
        // Just calling connect() again doesn't seem to do the trick (it leads
        // to odd queued up events and errors upon subsequent beanstalk
        // commands), so reset a few internal things on the client so the
        // reconnection works properly.
        client.end();
        client.handlers = [];
        client.buffer = undefined;

        client.connect();
      }, 100);
    }
  });

  // Add a custom "exit" method so we know when we explicitly want to close the
  // beanstalk connection (versus unexpected closings).
  client.exit = function() {
    client.exitingProcess = true;
    client.end();
  };

  client.connect();
};
