'use strict';

var async = require('async'),
    forever = require('forever-monitor'),
    fs = require('fs'),
    net = require('net'),
    path = require('path');

global.nginxPidFile = path.resolve(__dirname, '../tmp/nginx.pid');
before(function nginxStart(done) {
  this.timeout(5000);

  if(fs.existsSync(global.nginxPidFile)) {
    var pid = fs.readFileSync(global.nginxPidFile);
    if(pid) {
      forever.kill(pid, false, 'SIGKILL');
    }
  }

  // Spin up the nginx process.
  global.nginxServer = new (forever.Monitor)(['nginx', '-p', path.resolve(__dirname, '../..') + '/', '-c', 'conf/nginx.conf'], {
    max: 1,
    silent: true,
    pidFile: global.nginxPidFile,
  });

  var nginxOutput = '';
  global.nginxServer.on('stderr', function(data) {
    nginxOutput += data.toString();
  });

  global.nginxServer.on('stdout', function(data) {
    nginxOutput += data.toString();
  });

  // Make sure the nginx process doesn't just quickly die on startup
  // (for example, if the port is already in use).
  var exitListener = function () {
    // Delay exiting, so stdout/stderr can be captured and displayed. I think
    // this is an odd-bug with forever-monitor, where the output gets weird on
    // immediate exits. Possibly related to similar oddities seen when trying
    // to use log files: https://github.com/nodejitsu/forever-monitor/issues/36
    setTimeout(function() {
      console.error('\nFailed to start nginx server:');
      console.error(nginxOutput);
      process.exit(1);
    }, 250);
  };
  global.nginxServer.on('exit', exitListener);

  setTimeout(function() {
    if(exitListener) {
      global.nginxServer.removeListener('exit', exitListener);
      exitListener = null;
    }
  }, 1000);

  global.nginxServer.on('start', function(process, data) {
    fs.writeFileSync(global.nginxPidFile, data.pid);

    // Wait until we're able to establish a connection before moving on.
    var connected = false;
    async.until(function() {
      return connected;
    }, function(callback) {
      net.connect({
        port: 9333,
      }).on('connect', function() {
        connected = true;
        setTimeout(callback, 1000);
      }).on('error', function() {
        setTimeout(callback, 20);
      });
    }, done);
  });

  global.nginxServer.start();
});
