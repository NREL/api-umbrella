'use strict';

module.exports = function(callback) {
  var _ = require('lodash'),
      async = require('async'),
      config = require('api-umbrella-config').global(),
      fs = require('fs'),
      glob = require('glob'),
      handlebars = require('handlebars'),
      mkdirp = require('mkdirp'),
      path = require('path'),
      posix = require('posix'),
      yaml = require('js-yaml');

  var gatekeeperHosts = _.times(config.get('gatekeeper.workers'), function(n) {
    var port = parseInt(config.get('gatekeeper.starting_port'), 10) + n;
    return {
      port: port,
      host: config.get('gatekeeper.host') + ':' + port,
      process_name: 'gatekeeper' + (n + 1),
    };
  });

  var templateConfig = _.extend({}, config.getAll(), {
    api_umbrella_config_runtime_file: config.path,
    api_umbrella_config_args: '--config ' + config.path,
    gatekeeper_hosts: gatekeeperHosts,
    gatekeeper_supervisor_process_names: _.pluck(gatekeeperHosts, 'process_name'),
    test_env: (config.get('app_env') === 'test'),
    development_env: (config.get('app_env') === 'development'),
    primary_hosts: _.filter(config.get('hosts'), function(host) { return !host.secondary; }),
    secondary_hosts: _.filter(config.get('hosts'), function(host) { return host.secondary; }),
    has_default_host: (_.where(config.get('hosts'), { default: true }).length > 0),
    supervisor_conditional_user: (config.get('user')) ? 'user=' + config.get('user') : '',
    mongodb_yaml: yaml.safeDump(_.merge({
      systemLog: {
        path: path.join(config.get('log_dir'), 'mongod.log'),
      },
      storage: {
        dbPath: path.join(config.get('db_dir'), 'mongodb'),
      },
    }, config.get('mongodb.embedded_server_config'))),
    elasticsearch_yaml: yaml.safeDump(_.merge({
      path: {
        conf: path.join(config.get('etc_dir'), 'elasticsearch'),
        data: path.join(config.get('db_dir'), 'elasticsearch'),
        logs: path.join(config.get('log_dir')),
      },
    }, config.get('elasticsearch.embedded_server_config'))),
  });

  var templateRoot = path.resolve(__dirname, '../templates/etc');
  glob(path.join(templateRoot, '**/*'), function(error, templatePaths) {
    async.each(templatePaths, function(templatePath, eachCallback) {
      // We only want template files, so skip over directories returned by
      // the globbing.
      if(fs.statSync(templatePath).isDirectory()) { return eachCallback(); }

      // Skip over any test environment-only template files if we're not
      // running in the test environment.
      if(config.get('app_env') !== 'test' && _.contains(templatePath, '/test_env/')) {
        return eachCallback();
      }

      var installPath = templatePath.replace(/\.hbs$/, '');
      installPath = installPath.replace(templateRoot, '');
      installPath = path.join(config.get('etc_dir'), installPath);

      mkdirp.sync(path.dirname(installPath));

      // For the api_backends template, we don't have the necessary API backend
      // information yet, so just make sure it exists and is writable. This
      // template gets managed by the config_reloader worker process after
      // things are started.
      if(_.contains(installPath, 'nginx/api_backends.conf')) {
        // Make sure the file exists.
        fs.closeSync(fs.openSync(installPath, 'a'));

        // Make sure it's writable in case the config-reloader process is
        // running as the less-privileged user.
        if(config.get('user')) {
          var uid = posix.getpwnam(config.get('user')).uid;
          var gid = posix.getgrnam(config.get('group')).gid;

          fs.chownSync(installPath, uid, gid);
        }

      // All other templates get parsed and written.
      } else {
        var content = fs.readFileSync(templatePath).toString();
        if(/\.hbs$/.test(templatePath)) {
          var template = handlebars.compile(content);
          content = template(templateConfig);
        }

        fs.writeFileSync(installPath, content);
      }

      eachCallback();
    }.bind(this), callback);
  }.bind(this));
};
