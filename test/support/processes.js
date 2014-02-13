'use strict';

require('../test_helper');

var async = require('async'),
    config = require('../../gatekeeper/lib/config'),
    fs = require('fs'),
    net = require('net'),
    path = require('path'),
    spawn = require('child_process').spawn;

before(function(done) {
  this.timeout(10000);

  var configFile = path.resolve(__dirname, '../config/nginx.conf');

  // Delete the generated config file before running tests, so we know when the
  // config_reloader process has finished booting. This ensures we wait until
  // the current configuration is in place.
  if(fs.existsSync(configFile)) {
    fs.unlinkSync(configFile);
  }

  var processConfigs = [
    {
      command: 'api_umbrella_gatekeeper',
      args: ['-p', config.get('proxy.port')],
      options: {
        cwd: path.resolve(__dirname, '../../gatekeeper'),
      },
      wait: {
        port: config.get('proxy.port'),
      },
    },
    {
      command: 'api_umbrella_logging',
      options: {
        cwd: path.resolve(__dirname, '../../gatekeeper'),
      },
    },
    {
      command: 'api_umbrella_config_reloader',
      options: {
        cwd: path.resolve(__dirname, '../../gatekeeper'),
      },
      wait: {
        file: configFile,
      },
    },
    {
      command: 'api_umbrella_distributed_rate_limits_sync',
      options: {
        cwd: path.resolve(__dirname, '../../gatekeeper'),
      },
    },
    {
      command: 'varnishd',
      args: [
        '-F',
        '-a', ':' + config.get('varnish.port'),
        '-f', path.resolve(__dirname, '../../config/varnish.vcl'),
        '-t', '0',
        '-n', 'api_umbrella',
      ],
      wait: {
        port: config.get('varnish.port'),
      },
    },
    {
      command: 'nginx',
      args: ['-c', path.resolve(__dirname, '../../config/nginx/nginx.conf')],
      wait: {
        port: config.get('redis.port'),
      },
    },
  ];

  async.eachSeries(processConfigs, function(processConfig, eachCallback) {
    // Spin up the process;
    var server = spawn(processConfig.command, processConfig.args, processConfig.options);

    var stdout = '';
    var stderr = '';

    server.stdout.on('data', function(message) {
      stdout += message.toString();
    });

    server.stderr.on('data', function(message) {
      stderr += message.toString();
    });

    server.on('close', function(code) {
      console.error(processConfig.command + ' exited with:', code);
      console.error(processConfig.command + ' STDERR:', stderr);
      process.exit(1);
    });

    // Ensure that the process is killed when the tests end.
    process.on('exit', function() {
      server.kill('SIGQUIT');

      setTimeout(function() {
        server.kill('SIGKILL');
      }, 500);
    });

    if(!processConfig.wait) {
      eachCallback(null);
    } else {
      if(processConfig.wait.port) {
        process.stdout.write('Waiting for ' + processConfig.command + ' (port ' + processConfig.wait.port + ')... ');

        // Wait until we're able to establish a connection before moving on.
        var connected = false;
        async.until(function() {
          return connected;
        }, function(untilCallback) {
          net.connect({
            port: processConfig.wait.port,
          }).on('connect', function() {
            console.info('Connected');
            connected = true;
            untilCallback();
          }).on('error', function() {
            setTimeout(untilCallback, 20);
          });
        }, eachCallback);
      } else if(processConfig.wait.file) {
        process.stdout.write('Waiting for ' + processConfig.command + ' (file ' + processConfig.wait.file + ')... ');

        // Wait until we're able to establish a connection before moving on.
        var exists = false;
        async.until(function() {
          return exists;
        }, function(untilCallback) {
          fs.exists(processConfig.wait.file, function(fileExists) {
            if(fileExists) {
              console.info('Exists');
              exists = true;
              untilCallback();
            } else {
              setTimeout(untilCallback, 20);
            }
          });
        }, eachCallback);
      }
    }
  }, done);
});
