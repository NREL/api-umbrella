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
        exec = require('child_process').exec;

    async.timesSeries(20, function(index, next) {
      var runNum = index + 1;
      process.stdout.write('Run ' + runNum + ' ');
      var progress = setInterval(function() {
        process.stdout.write('.');
      }, 5000);

      var startTime = process.hrtime();
      exec('./node_modules/.bin/grunt 2>&1', function(error, stdout, stderr) {
        clearInterval(progress);

        var duration = process.hrtime(startTime);
        console.info(' ' + duration[0] + 's');

        if(error !== null) {
          console.info('Run ' + runNum + ' encountered an error');
          console.info('STDOUT: ', stdout);
          console.info('STDERR: ', stderr);
        }

        next(error);
      });
    }, function(error) {
      done(error);
    });
  });

  grunt.registerTask('multiLongConnectionDrops', 'Run all the tests multiple times', function() {
    var done = this.async();

    var async = require('async'),
        exec = require('child_process').exec;

    async.timesSeries(20, function(index, next) {
      var runNum = index + 1;
      process.stdout.write('Run ' + runNum + ' ');
      var progress = setInterval(function() {
        process.stdout.write('.');
      }, 5000);

      var startTime = process.hrtime();
      process.env.CONNECTION_DROPS_DURATION = 10 * 60;
      exec('./node_modules/.bin/mocha test/integration/dns.js -g "handles ip changes without dropping any connections" 2>&1', function(error, stdout, stderr) {
        clearInterval(progress);

        var duration = process.hrtime(startTime);
        console.info(' ' + duration[0] + 's');

        if(error !== null) {
          console.info('Run ' + runNum + ' encountered an error');
          console.info('STDOUT: ', stdout);
          console.info('STDERR: ', stderr);
        }

        next(error);
      });
    }, function(error) {
      done(error);
    });
  });
};
