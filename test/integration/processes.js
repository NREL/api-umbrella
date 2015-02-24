'use strict';

require('../test_helper');

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    async = require('async'),
    execFile = require('child_process').execFile,
    Factory = require('factory-lady'),
    fs = require('fs'),
    ipaddr = require('ipaddr.js'),
    mongoose = require('mongoose'),
    path = require('path'),
    processEnv = require('../../lib/process_env'),
    request = require('request'),
    Tail = require('tail').Tail;

var config = apiUmbrellaConfig.load(path.resolve(__dirname, '../config/test.yml'));

describe('server processes', function() {
  describe('nginx', function() {
    it('does not leak file descriptors across reloads', function(done) {
      this.timeout(30000);

      var configPath = processEnv.supervisordConfigPath();
      var execOpts = { env: processEnv.env() };
      execFile('supervisorctl', ['-c', configPath, 'pid', 'router-nginx'], execOpts, function(error, stdout, stderr) {
        if(error) {
          return done('Error fetching nginx pid: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr);
        }

        var parentPid = stdout.trim();

        async.timesSeries(10, function(index, next) {
          execFile('supervisorctl', ['-c', configPath, 'kill', 'HUP', 'router-nginx'], execOpts, function(error, stdout, stderr) {
            if(error) {
              return next('Error reloading nginx: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr);
            }

            setTimeout(function() {
              execFile('lsof', ['-R', '-c', 'nginx'], execOpts, function(error, stdout, stderr) {
                if(error) {
                  return next('Error gathering lsof details: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr);
                }

                var lines = _.filter(stdout.split('\n'), function(line) {
                  var columns = line.split(/\s+/);
                  return columns[2] == parentPid;
                });
                setTimeout(function() {
                  next(null, lines.length);
                }, 500);
              });
            }, 500);
          });
        }, function(error, descriptorCounts) {
          if(error) {
            return done(error);
          }

          _.uniq(descriptorCounts).length.should.eql(1);
          done();
        });
      });
    });
  });
});
