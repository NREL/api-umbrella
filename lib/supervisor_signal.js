'use strict';

var execFile = require('child_process').execFile,
    processEnv = require('./process_env');

// Send kill signals to supervisor processes (to reload or reopen log files).
//
// Note: We used to use the supervisor mr.laforge plugin to send kill signals,
// but it appears as though supervisor sometimes erroneously returns a child
// process's PID as 0 (I think mainly during startup). This would lead to
// mr.laforge trying to kill PID 0, which would cause weird things to happen. I
// don't think we actually saw this behavior too much on server environments,
// but it did suddenly start to happen semi-frequently during our test suite
// (so the SIGHUPs sent to reload nginx internally would end up triggering a
// SIGHUP on PID 0, which would kill the grunt test runner with a "Hangup"
// error). So instead of all that, we'll handle process killing ourselves so we
// can double check for this weird PID 0 issue.
module.exports = function(processName, signal, callback) {
  execFile('supervisorctl', ['-c', processEnv.supervisordConfigPath(), 'pid', processName], { env: processEnv.env() }, function(error, stdout, stderr) {
    if(error) {
      return callback('Error calling supervisorctl for ' + processName + ' PID (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
    }

    if(!stdout || !/^\d+$/.test(stdout.trim())) {
      return callback('No PID returned by supervisorctl for ' + processName + ' PID (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
    }

    var pid = parseInt(stdout, 10);
    if(pid === 0) {
      // If the PID is unexpectedly 0, make 1 more attempt after waiting for a
      // second (since this seems like it's usually a transient response by
      // supervisor).
      setTimeout(function() {
        execFile('supervisorctl', ['-c', processEnv.supervisordConfigPath(), 'pid', processName], { env: processEnv.env() }, function(error, stdout, stderr) {
          pid = parseInt(stdout, 10);
          if(pid === 0) {
            return callback('PID returned by supervisorctl unexpectedly 0 for ' + processName + ' (STDOUT: ' + stdout + ', STDERR: ' + stderr + ')');
          } else {
            process.kill(pid, signal);
            callback();
          }
        });
      }, 1000);
    } else {
      process.kill(pid, signal);
      callback();
    }
  });
};
