'use strict';

module.exports = function(options, reloadCallback) {
  var _ = require('lodash'),
      config = require('api-umbrella-config').global(),
      async = require('async'),
      execFile = require('child_process').execFile,
      logger = require('./logger'),
      processEnv = require('./process_env'),
      supervisorSignal = require('./supervisor_signal');

  var configPath = processEnv.supervisordConfigPath();
  var execOpts = {
    env: processEnv.env(),
  };

  logger.info('Begin reloading api-umbrella...');
  execFile('supervisorctl', ['-c', configPath, 'update'], execOpts, function(error, stdout, stderr) {
    if(error) {
      logger.error({ err: error, stdout: stdout, stderr: stderr }, 'supervisorctl update error');
      return false;
    }

    var tasks = [];

    if((_.isEmpty(options) || options.router) && config.get('service_router_enabled')) {
      tasks = tasks.concat([
        function(callback) {
          logger.info('Reloading router-nginx...');
          supervisorSignal('router-nginx', 'SIGHUP', function(error) {
            logger.info('Finished reloading router-nginx', error);
            callback(error);
          });
        },
        function(callback) {
          logger.info('Reloading gatekeeper...');
          execFile('supervisorctl', ['-c', configPath, 'serialrestart', 'gatekeeper:*'], execOpts, function(error) {
            logger.info('Finished reloading gatekeeper', error);
            callback(error);
          });
        },
        function(callback) {
          logger.info('Reloading config-reloader...');
          execFile('supervisorctl', ['-c', configPath, 'restart', 'config-reloader'], execOpts, function(error) {
            logger.info('Finished reloading config-reloader', error);
            callback(error);
          });
        },
        function(callback) {
          logger.info('Reloading distributed-rate-limits-sync...');
          execFile('supervisorctl', ['-c', configPath, 'restart', 'distributed-rate-limits-sync'], execOpts, function(error) {
            logger.info('Finished reloading distributed-rate-limits-sync', error);
            callback(error);
          });
        },
        function(callback) {
          logger.info('Reloading log-processor...');
          execFile('supervisorctl', ['-c', configPath, 'restart', 'log-processor'], execOpts, function(error) {
            logger.info('Finished reloading log-processor', error);
            callback(error);
          });
        },
        function(callback) {
          logger.info('Reloading router-log-listener...');
          execFile('supervisorctl', ['-c', configPath, 'restart', 'router-log-listener'], execOpts, function(error) {
            logger.info('Finished reloading router-log-listener', error);
            callback(error);
          });
        },
      ]);
    }

    if((_.isEmpty(options) || options.web) && config.get('service_web_enabled')) {
      tasks = tasks.concat([
        function(callback) {
          logger.info('Reloading web-nginx...');
          supervisorSignal('web-nginx', 'SIGHUP', function(error) {
            logger.info('Finished reloading web-nginx', error);
            callback(error);
          });
        },
        function(callback) {
          logger.info('Reloading web-puma...');
          supervisorSignal('web-puma', 'SIGUSR2', function(error) {
            logger.info('Finished reloading web-puma', error);
            callback(error);
          });
        },
        function(callback) {
          logger.info('Reloading web-delayed-job...');
          execFile('supervisorctl', ['-c', configPath, 'restart', 'web-delayed-job'], execOpts, function(error) {
            logger.info('Finished reloading web-delayed-job', error);
            callback(error);
          });
        },
      ]);
    }

    if(tasks.length > 0) {
      async.parallel(tasks, function(error) {
        if(error) {
          logger.error({ err: error }, 'Error reloading api-umbrella');
        } else {
          logger.info('Finished reloading api-umbrella');
        }

        reloadCallback();
      });
    } else {
      reloadCallback();
    }
  }.bind(this));
};
