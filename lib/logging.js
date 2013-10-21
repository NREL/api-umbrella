var variouscluster = require('various-cluster');

variouscluster.init({
  title: 'api_umbrella_logging',
  workers: [
    {
      title: 'api-umbrella: router_log_listener',
      exec: 'lib/router_log_listener.js',
      count: 1,
      shutdownTimeout: 10000,
      shutdownAll: true,
    },
    {
      title: 'api-umbrella: log_processor',
      exec: 'lib/log_processor.js',
      count: 1,
      shutdownTimeout: 10000,
      shutdownAll: true,
    },
  ],
});
