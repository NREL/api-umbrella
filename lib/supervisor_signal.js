'use strict';

var supervisorPid = require('./supervisor_pid');

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
  supervisorPid(processName, function(error, pid) {
    if(error) {
      return callback(error);
    }

    process.kill(pid, signal);
    callback();
  });
};
