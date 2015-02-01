'use strict';

var fs = require('fs');

after(function nginxClose(done) {
  if(global.nginxServer.running) {
    global.nginxServer.on('exit', function() {
      done();
    });

    global.nginxServer.stop();
    fs.unlinkSync(global.nginxPidFile);
  } else {
    done();
  }
});
