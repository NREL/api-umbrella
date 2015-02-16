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

          //require: 'test/support/blanket'
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
        exec = require('child_process').exec;

    async.timesSeries(20, function(index, next) {
      process.stdout.write('Run ' + (index + 1) + ' ');
      var progress = setInterval(function() {
        process.stdout.write('.');
      }, 5000);

      var startTime = process.hrtime();
      exec('./node_modules/grunt-cli/bin/grunt 2>&1', function(error, stdout) {
        clearInterval(progress);

        var duration = process.hrtime(startTime);
        console.info(' ' + duration[0] + 's');

        if(error !== null) {
          console.info(stdout);
        }

        next();
      });
    }, function() {
      done();
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
