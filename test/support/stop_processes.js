'use strict';

function killApiUmbrellaServer(callback) {
  if(global.apiUmbrellaServer) {
    if(callback) {
      global.apiUmbrellaServer.on('close', function() {
        callback();
      });
    }

    global.apiUmbrellaServer.kill();
  } else {
    if(callback) {
      callback();
    }
  }
}

after(function stopProcesses(done) {
  this.timeout(15000);
  killApiUmbrellaServer(done);
});

process.on('exit', function() {
  killApiUmbrellaServer();
});
