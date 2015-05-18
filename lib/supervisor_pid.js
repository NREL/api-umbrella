'use strict';

var async = require('async'),
    execFile = require('child_process').execFile,
    processEnv = require('./process_env');

// supervisorctl sometimes seems to report a processes's PID as 0. This is a
// wrapper to retry fetching the PID when it reports 0, since that seems to be
// a temporary issue.
module.exports = function(processName, callback) {
  var pid;
  var tries = 0;
  async.doUntil(function(untilCallback) {
    tries++;

    execFile('supervisorctl', ['-c', processEnv.supervisordConfigPath(), 'pid', processName], { env: processEnv.env() }, function(error, stdout, stderr) {
      if(error) {
        return untilCallback('Error calling supervisorctl for ' + processName + ' PID (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
      }

      if(!stdout || !/^\d+$/.test(stdout.trim())) {
        return untilCallback('No PID returned by supervisorctl for ' + processName + ' PID (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
      }

      pid = parseInt(stdout, 10);
      if(pid === 0) {
        setTimeout(untilCallback, 300);
      } else {
        untilCallback();
      }
    });
  }, function() {
    return (pid && pid !== 0) || tries > 5;
  }, function(error) {
    if(error) {
      callback(error);
    } else if(pid === 0) {
      return callback('PID returned by supervisorctl unexpectedly 0 for ' + processName);
    } else {
      callback(error, pid);
    }
  });
};
