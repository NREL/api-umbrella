'use strict';

module.exports = function(grunt) {
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.loadNpmTasks('grunt-mocha-test');
  grunt.loadNpmTasks('grunt-shell');

  grunt.initConfig({
    jshint: {
      options: {
        jshintrc: '.jshintrc'
      },
      all: [
        '.eastrc',
        'Gruntfile.js',
        'bin/api-umbrella-*',
        'index.js',
        'lib/**/*.js',
        'migrations/**/*.js',
        'scripts/*',
        'test/**/*.js',
      ],
    },

    mochaTest: {
      test: {
        options: {
          reporter: 'spec',

          // Force colors for the output of mutliTest
          colors: true,

          // Increase the default timeout from 2 seconds to 4 seconds. We'll
          // see if this helps with sporadic issues in the CI environment.
          timeout: 4000,
        },
        src: ['test/**/*.js']
      },
      coverage: {
        options: {
          reporter: 'mocha-lcov-reporter',
          quiet: true,
          captureFile: 'test/tmp/coverage.lcov'
        },
        src: ['test/**/*.js'],
      },
    },

    shell: {
      coveralls: {
        command: 'cat test/tmp/coverage.lcov | ./node_modules/.bin/coveralls',
        failOnError: true
      },
    },
  });

  grunt.registerTask('default', [
    'test',
  ]);

  grunt.registerTask('test', [
    'jshint',
    'mochaTest',
  ]);

  // Run the full test suite 20 times. Only print the output when errors are
  // encountered. This is to try to make it easier to track down sporadic test
  // issues that only happen occasionally.
  grunt.registerTask('multiTest', 'Run all the tests multiple times', function() {
    var done = this.async();

    var async = require('async'),
        exec = require('child_process').exec,
        fs = require('fs');

    async.timesSeries(20, function(index, next) {
      var runNum = index + 1;
      process.stdout.write('Run ' + runNum + ' ');
      var progress = setInterval(function() {
        process.stdout.write('.');
      }, 5000);

      var startTime = process.hrtime();
      var logPath = '/tmp/api-umbrella-multi-test.log';
      exec('./node_modules/.bin/grunt > ' + logPath + ' 2>&1', function(error) {
        clearInterval(progress);

        var duration = process.hrtime(startTime);
        console.info(' ' + duration[0] + 's');

        if(error) {
          console.info('Run ' + runNum + ' encountered an error: ', error);
          console.info(fs.readFileSync(logPath).toString());
        }

        next(error);
      });
    }, function(error) {
      if(error) {
        console.info('Error during multiple runs: ', error);
      }

      done(error);
    });
  });

  grunt.registerTask('multiLongConnectionDrops', 'Run all the tests multiple times', function() {
    var done = this.async();

    var async = require('async'),
        exec = require('child_process').exec,
        fs = require('fs');

    async.timesSeries(20, function(index, next) {
      var runNum = index + 1;
      process.stdout.write('Run ' + runNum + ' ');
      var progress = setInterval(function() {
        process.stdout.write('.');
      }, 5000);

      var startTime = process.hrtime();
      process.env.CONNECTION_DROPS_DURATION = 10 * 60;
      var logPath = '/tmp/api-umbrella-multi-long-connection-drops.log';
      exec('./node_modules/.bin/mocha test/integration/dns.js -g "handles ip changes without dropping any connections" > ' + logPath + ' 2>&1', function(error) {
        clearInterval(progress);

        var duration = process.hrtime(startTime);
        console.info(' ' + duration[0] + 's');

        if(error) {
          console.info('Run ' + runNum + ' encountered an error: ', error);
          console.info(fs.readFileSync(logPath).toString());
        }

        next(error);
      });
    }, function(error) {
      if(error) {
        console.info('Error during multiple runs: ', error);
      }

      done(error);
    });
  });

  grunt.registerTask('cleanup_logs', 'Re-process any failed or stuck log jobs', function() {
    var async = require('async'),
        config = require('api-umbrella-config'),
        redis = require('redis');

    var done = this.async();
    var redisClient = redis.createClient(config.get('redis.port'), config.get('redis.host'));

    var queues = ['cv:log_queue:processing', 'cv:log_queue:failed'];
    async.eachSeries(queues, function(queue, queueCallback) {
      redisClient.zrange(queue, 0, -1, function(error, ids) {
        console.info('Re-processing ' + ids.length + ' logs for ' + queue);

        async.eachSeries(ids, function(id, callback) {
          redisClient.hgetall('log:' + id, function(error, log) {
            if(log) {
              console.info('Re-processing ' + id);
              var processAt = Date.now();
              redisClient.multi()
                .zrem('cv:log_queue:processing', id)
                .srem('cv:log_queue:committed', id)
                .zadd('log_jobs', processAt, id, callback)
                .exec(callback);
            } else {
              console.info('Cleaning up ' + id);
              redisClient.multi()
                .zrem('cv:log_queue:processing', id)
                .zrem('cv:log_queue:failed', id)
                .srem('cv:log_queue:committed', id)
                .exec(callback);
            }
          });
        }, queueCallback);
      });
    }, done);
  });
};
