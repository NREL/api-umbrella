'use strict';

after(function stopProcesses(done) {
  this.timeout(15000);

  if(this.router) {
    this.router.stop(done);
  }
});
