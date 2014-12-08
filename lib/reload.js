'use strict';

module.exports = function(options, reloadCallback) {
  var _ = require('lodash'),
      config = require('api-umbrella-config').global(),
      async = require('async'),
      execFile = require('child_process').execFile,
      logger = require('./logger'),
      processEnv = require('./process_env');

  var configPath = processEnv.supervisordConfigPath();
  var execOpts = {
    env: processEnv.env(),
  };

  logger.info('Begin reloading api-umbrella...');
  execFile('supervisorctl', ['-c', configPath, 'update'], execOpts, function(error, stdout, stderr) {
    if(error) {
      logger.error('supervisorctl update error: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr);
      return false;
    }

    var tasks = [];

    if((_.isEmpty(options) || options.router) && config.get('service_router_enabled')) {
      tasks = tasks.concat([
        function(callback) {
          logger.info('Reloading router-nginx...');
          execFile('supervisorctl', ['-c', configPath, 'kill', 'HUP', 'router-nginx'], execOpts, callback);
        },
        function(callback) {
          logger.info('Reloading gatekeeper...');
          execFile('supervisorctl', ['-c', configPath, 'serialrestart', 'gatekeeper:*'], execOpts, callback);
        },
        function(callback) {
          logger.info('Reloading config-reloader...');
          execFile('supervisorctl', ['-c', configPath, 'restart', 'config-reloader'], execOpts, callback);
        },
        function(callback) {
          logger.info('Reloading distributed-rate-limits-sync...');
          execFile('supervisorctl', ['-c', configPath, 'restart', 'distributed-rate-limits-sync'], execOpts, callback);
        },
        function(callback) {
          logger.info('Reloading log-processor...');
          execFile('supervisorctl', ['-c', configPath, 'restart', 'log-processor'], execOpts, callback);
        },
        function(callback) {
          logger.info('Reloading router-log-listener...');
          execFile('supervisorctl', ['-c', configPath, 'restart', 'router-log-listener'], execOpts, callback);
        },
      ]);
    }

    if((_.isEmpty(options) || options.web) && config.get('service_web_enabled')) {
      tasks = tasks.concat([
        function(callback) {
          logger.info('Reloading web-nginx...');
          execFile('supervisorctl', ['-c', configPath, 'kill', 'HUP', 'web-nginx'], execOpts, callback);
        },
        function(callback) {
          logger.info('Reloading web-puma...');
          execFile('supervisorctl', ['-c', configPath, 'kill', 'USR2', 'web-puma'], execOpts, callback);
        },
        function(callback) {
          logger.info('Reloading web-delayed-job...');
          execFile('supervisorctl', ['-c', configPath, 'restart', 'web-delayed-job'], execOpts, callback);
        },
      ]);
    }

    if(tasks.length > 0) {
      async.parallel(tasks, function(error) {
        if(error) {
          logger.error('Error reloading api-umbrella: ', error);
          reloadCallback(error);
        } else {
          logger.info('Finished reloading api-umbrella');
          reloadCallback();
        }
      });
    } else {
      reloadCallback();
    }
  }.bind(this));
};
