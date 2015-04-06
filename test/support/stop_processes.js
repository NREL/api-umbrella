'use strict';

after(function stopProcesses(done) {
  this.timeout(30000);

  if(this.router) {
    this.router.stop(done);
  }
});
