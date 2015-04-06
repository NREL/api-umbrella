'use strict';

module.exports = function(grunt) {
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.loadNpmTasks('grunt-mocha-test');

  grunt.initConfig({
    jshint: {
      options: {
        jshintrc: '.jshintrc'
      },
      all: [
        '*.js',
        '.eastrc',
        'lib/**/*.js',
        'migrations/**/*.js',
        'bin/*',
        'test/**/*.js',
      ],
    },

    mochaTest: {
      test: {
        options: {
          reporter: 'spec',

          // Force colors for the output of mutliTest
          colors: true,
        },
        src: ['test/**/*.js']
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
};
