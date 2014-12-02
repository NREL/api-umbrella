'use strict';

require('../test_helper');

var _ = require('lodash'),
    apiUmbrellaConfig = require('api-umbrella-config'),
    async = require('async'),
    execFile = require('child_process').execFile,
    Factory = require('factory-lady'),
    mkdirp = require('mkdirp'),
    path = require('path'),
    processEnv = require('../../lib/process_env'),
    request = require('request'),
    rimraf = require('rimraf');

var config = apiUmbrellaConfig.load(path.resolve(__dirname, '../config/test.yml'));

describe('logging', function() {
  // Clear all the queued beanstalk jobs before running these logging tests, so
  // we ensure we don't have a big backlog of logs to process from tests that
  // ran before this suite. This ensures we're testing the logging specific
  // functionality with a fresh-slate and it's performance won't be impacted by
  // previous tests.
  before(function clearBeanstalkData(done) {
    this.timeout(10000);

    var configPath = processEnv.supervisordConfigPath();
    var execOpts = {
      env: processEnv.env(),
    };

    // Beanstalk doesn't have a super easy way to delete all jobs (without
    // peeking and deleting records one at a time), so let's stop beanstalk,
    // wipe the directory, and start it back up.
    execFile('supervisorctl', ['-c', configPath, 'stop', 'beanstalkd'], execOpts, function(error) {
      if(error) { return done(error); }

      rimraf.sync(path.join(config.get('db_dir'), 'beanstalkd'));
      mkdirp.sync(path.join(config.get('db_dir'), 'beanstalkd'));

      execFile('supervisorctl', ['-c', configPath, 'start', 'beanstalkd'], execOpts, done);
    });
  });

  beforeEach(function(done) {
    this.uniqueQueryId = process.hrtime().join('-') + '-' + Math.random();
    Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
      this.user = user;
      this.apiKey = user.api_key;
      this.options = {
        headers: {
          'X-Api-Key': this.apiKey,
          'X-Disable-Router-Connection-Limits': 'yes',
          'X-Disable-Router-Rate-Limits': 'yes',
        },
        qs: {
          'unique_query_id': this.uniqueQueryId,
        },
        agentOptions: {
          maxSockets: 500,
        },
      };

      done();
    }.bind(this));
  });

  function waitForLog(uniqueQueryId, options, done) {
    if(!done && _.isFunction(options)) {
      done = options;
      options = null;
    }

    options = options || {};
    options.timeout = options.timeout || 3500;
    options.minCount = options.minCount || 1;

    var response;
    var timedOut = false;
    setTimeout(function() {
      timedOut = true;
    }, options.timeout);

    async.doWhilst(function(callback) {
      global.elasticsearch.search({
        q: 'request_query.unique_query_id:"' + uniqueQueryId + '"',
      }, function(error, res) {
        if(error) {
          callback(error);
        } else {
          if(res && res.hits && res.hits.total >= options.minCount) {
            response = res;
            callback();
          } else {
            setTimeout(callback, 50);
          }
        }
      });
    }, function() {
      return (!response && !timedOut);
    }, function(error) {
      if(timedOut) {
        return done('Timed out fetching log for request_query.unique_query_id:' + uniqueQueryId);
      }

      if(error) {
        return done('Error fetching log for request_query.unique_query_id:' + uniqueQueryId + ': ' + error);
      }

      if(!response || (options.minCount === 1 && response.hits.total !== 1)) {
        return done('Unexpected log response for ' + uniqueQueryId + ': ' + response);
      }

      var hit = response.hits.hits[0];
      var record = hit._source;
      done(error, response, hit, record);
    });
  }

  function itLogsBaseFields(record, uniqueQueryId, user) {
    record.request_at.should.match(/^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d\.\d\d\dZ$/);
    record.request_hierarchy.should.be.an('array');
    record.request_hierarchy.length.should.be.gte(1);
    record.request_host.should.eql('localhost');
    record.request_ip.should.match(/^\d+\.\d+\.\d+\.\d+$/);
    record.request_method.should.eql('GET');
    record.request_path.should.be.a('string');
    record.request_path.length.should.be.gte(1);
    record.request_query.should.be.a('object');
    Object.keys(record.request_query).length.should.be.gte(1);
    record.request_query.unique_query_id.should.eql(uniqueQueryId);
    record.request_scheme.should.eql('http');
    record.request_size.should.be.a('number');
    record.request_url.should.be.a('string');
    record.request_url.should.match(/^http:\/\/localhost:9080\//);
    record.response_size.should.be.a('number');
    record.response_status.should.be.a('number');
    record.response_time.should.be.a('number');

    if(user) {
      record.api_key.should.eql(user.api_key);
      record.user_email.should.eql(user.email);
      record.user_id.should.eql(user.id);
      record.user_registration_source.should.eql('web');
    }
  }

  function itLogsBackendFields(record) {
    record.internal_gatekeeper_time.should.be.a('number');
    record.internal_response_time.should.be.a('number');
    record.backend_response_time.should.be.a('number');
  }

  function itDoesNotLogBackendFields(record) {
    should.not.exist(record.internal_gatekeeper_time);
    should.not.exist(record.internal_response_time);
    should.not.exist(record.backend_response_time);
  }


  it('logs all the expected response fileds (for a non-chunked, non-gzipped response)', function(done) {
    this.timeout(4500);
    var options = _.merge({}, this.options, {
      headers: {
        'Accept': 'text/plain; q=0.5, text/html',
        'Accept-Encoding': 'compress, gzip',
        'Connection': 'close',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': 'http://foo.example',
        'User-Agent': 'curl/7.37.1',
        'Referer': 'http://example.com',
        'X-Forwarded-For': '1.2.3.4, 4.5.6.7, 10.10.10.11, 10.10.10.10, 192.168.12.0, 192.168.13.255',
      },
      auth: {
        user: 'basic-auth-username-example',
        pass: 'my-secret-password',
      },
    });

    delete options.qs;

    var requestUrl = 'http://localhost:9080/logging-example/foo/bar/?unique_query_id=' + this.uniqueQueryId + '&url1=http%3A%2F%2Fexample.com%2F%3Ffoo%3Dbar%26foo%3Dbar%20more+stuff&url2=%ED%A1%BC&url3=https%3A//example.com/foo/%D6%D0%B9%FA%BD%AD%CB%D5%CA%A1%B8%D3%D3%DC%CF%D8%D2%BB%C2%A5%C5%CC%CA%C0%BD%F5%BB%AA%B3%C7200%D3%E0%D2%B5%D6%F7%B9%BA%C2%F2%B5%C4%C9%CC%C6%B7%B7%BF%A3%AC%D2%F2%BF%AA%B7%A2%C9%CC%C5%DC%C2%B7%D2%D1%CD%A3%B9%A420%B8%F6%D4%C2%A3%AC%D2%B5%D6%F7%C4%C3%B7%BF%CE%DE%CD%FB%C8%B4%D0%E8%BC%CC%D0%F8%B3%A5%BB%B9%D2%F8%D0%D0%B4%FB%BF%EE%A1%A3%CF%F2%CA%A1%CA%D0%CF%D8%B9%FA%BC%D2%D0%C5%B7%C3%BE%D6%B7%B4%D3%B3%BD%FC2%C4%EA%CE%DE%C8%CB%B4%A6%C0%ED%A1%A3%D4%DA%B4%CB%B0%B8%D6%D0%A3%AC%CE%D2%C3%C7%BB%B3%D2%C9%D3%D0%C8%CB%CA%A7%D6%B0%E4%C2%D6%B0/sites/default/files/googleanalytics/ga.js';
    request.get(requestUrl, options, function(error, response) {
      response.statusCode.should.eql(200);

      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        var fields = _.keys(record).sort();

        // Varnish randomly turns some non-chunked responses into chunked
        // responses, so this header may crop up, but we'll ignore thit for
        // this test's purposes.
        // See: https://www.varnish-cache.org/trac/ticket/1506
        // TODO: Remove if Varnish changes its behavior.
        fields = _.without(fields, 'response_transfer_encoding');

        fields.should.eql([
          'api_key',
          'backend_response_time',
          'internal_gatekeeper_time',
          'internal_response_time',
          'proxy_overhead',
          'request_accept',
          'request_accept_encoding',
          'request_at',
          'request_basic_auth_username',
          'request_connection',
          'request_content_type',
          'request_hierarchy',
          'request_host',
          'request_ip',
          'request_method',
          'request_origin',
          'request_path',
          'request_query',
          'request_referer',
          'request_scheme',
          'request_size',
          'request_url',
          'request_user_agent',
          'request_user_agent_family',
          'request_user_agent_type',
          'response_age',
          'response_content_length',
          'response_content_type',
          'response_server',
          'response_size',
          'response_status',
          'response_time',
          'user_email',
          'user_id',
          'user_registration_source',
        ]);

        record.api_key.should.eql(this.apiKey);
        record.backend_response_time.should.be.a('number');
        record.internal_gatekeeper_time.should.be.a('number');
        record.internal_response_time.should.be.a('number');
        record.proxy_overhead.should.be.a('number');
        record.request_accept.should.eql('text/plain; q=0.5, text/html');
        record.request_accept_encoding.should.eql('compress, gzip');
        record.request_at.should.match(/^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d\.\d\d\dZ$/);
        record.request_basic_auth_username.should.eql('basic-auth-username-example');
        record.request_connection.should.eql('close');
        record.request_content_type.should.eql('application/x-www-form-urlencoded');
        record.request_hierarchy.should.eql([
          '0/localhost/',
          '1/localhost/logging-example/',
          '2/localhost/logging-example/foo/',
          '3/localhost/logging-example/foo/bar',
        ]);
        record.request_host.should.eql('localhost');
        record.request_ip.should.eql('10.10.10.11');
        record.request_method.should.eql('GET');
        record.request_origin.should.eql('http://foo.example');
        record.request_path.should.eql('/logging-example/foo/bar/');
        Object.keys(record.request_query).sort().should.eql([
          'unique_query_id',
          'url1',
          'url2',
          'url3',
        ]);
        record.request_query.unique_query_id.should.eql(this.uniqueQueryId);
        record.request_query.url1.should.eql('http://example.com/?foo=bar&foo=bar more stuff');
        (new Buffer(record.request_query.url2)).toString('base64').should.eql('77+9');
        (new Buffer(record.request_query.url3)).toString('base64').should.eql('aHR0cHM6Ly9leGFtcGxlLmNvbS9mb28v77+90Lnvv73vv73vv73vv73vv73Koe+/ve+/ve+/ve+/ve+/ve+/vdK7wqXvv73vv73vv73vv73vv73xu6qz77+9MjAw77+977+90rXvv73vv73vv73vv73vv73vv73vv73vv73vv73vv73Gt++/ve+/ve+/ve+/ve+/vfK/qrfvv73vv73vv73vv73vv73Ct++/ve+/vc2j77+977+9MjDvv73vv73vv73Co++/vdK177+977+977+9w7fvv73vv73vv73vv73vv73ItO+/ve+/ve+/ve+/ve+/ve+/ve+/ve+/ve+/ve+/ve+/ve+/ve+/vdC077+977+97qGj77+977+9yqHvv73vv73vv73Yue+/ve+/ve+/ve+/vcW3w77Wt++/vdOz77+977+9Mu+/ve+/ve+/ve+/ve+/vcu077+977+977+977+92rTLsO+/ve+/vdCj77+977+977+977+9x7vvv73vv73vv73vv73vv73vv73vv73Kp9aw77+977+91rAvc2l0ZXMvZGVmYXVsdC9maWxlcy9nb29nbGVhbmFseXRpY3MvZ2EuanM=');
        record.request_referer.should.eql('http://example.com');
        record.request_scheme.should.eql('http');
        record.request_size.should.be.a('number');
        record.request_url.should.eql(requestUrl);
        record.request_user_agent.should.eql('curl/7.37.1');
        record.request_user_agent_family.should.eql('cURL');
        record.request_user_agent_type.should.eql('Library');
        record.response_age.should.eql(20);
        record.response_content_type.should.eql('text/plain; charset=utf-8');
        record.response_server.should.eql('nginx');
        record.response_size.should.be.a('number');
        record.response_status.should.eql(200);
        record.response_time.should.be.a('number');
        record.user_email.should.eql(this.user.email);
        record.user_id.should.eql(this.user.id);
        record.user_registration_source.should.eql('web');

        // Handle the edge-case that Varnish randomly turns non-chunked
        // responses into chunked responses.
        if(record.response_content_length) {
          record.response_content_length.should.eql(5);
        } else {
          record.response_transfer_encoding.should.eql('chunked');
        }

        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs the extra expected fields for chunked or gzip responses', function(done) {
    this.timeout(4500);
    var options = _.merge({}, this.options, {
      gzip: true,
    });

    request.get('http://localhost:9080/compressible-chunked/10/1000', options, function(error, response) {
      response.statusCode.should.eql(200);

      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.response_content_encoding.should.eql('gzip');
        record.response_transfer_encoding.should.eql('chunked');

        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs the accept-encoding header prior to normalization', function(done) {
    this.timeout(4500);
    var options = _.merge({}, this.options, {
      headers: {
        'Accept-Encoding': 'compress, gzip',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_accept_encoding.should.eql('compress, gzip');
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs the external connection header and not the one used internally', function(done) {
    this.timeout(4500);
    var options = _.merge({}, this.options, {
      headers: {
        'Connection': 'close',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_connection.should.eql('close');
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs headers that contain quotes (to account for json escaping in nginx logs)', function(done) {
    this.timeout(4500);
    var options = _.merge({}, this.options, {
      headers: {
        'Referer': 'http://example.com/"foo\'bar',
        'Content-Type': 'text"\x22plain\'\\x22',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_referer.should.eql('http://example.com/"foo\'bar');
        record.request_content_type.should.eql('text""plain\'\\x22');
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs headers that contain special characters', function(done) {
    this.timeout(4500);
    var options = _.merge({}, this.options, {
      headers: {
        'Referer': 'http://example.com/!\\*^%#[]',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_referer.should.eql('http://example.com/!\\*^%#[]');
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs requests that exceed the nginx-level rate limits', function(done) {
    this.timeout(10000);
    async.times(100, function(index, callback) {
      var uniqueQueryId = this.uniqueQueryId + '-' + index;
      var options = _.merge({}, this.options, {
        qs: {
          'unique_query_id': uniqueQueryId,
        },
        headers: {
          'X-Disable-Router-Connection-Limits': 'no',
          'X-Disable-Router-Rate-Limits': 'no',
        },
      });

      request.get('http://localhost:9080/delay/1000', options, function(error, response) {
        callback(error, {
          uniqueQueryId: uniqueQueryId,
          statusCode: response.statusCode,
        });
      });
    }.bind(this), function(error, results) {
      var overLimits = _.filter(results, function(result) { return result.statusCode === 429; });
      overLimits.length.should.be.gte(1);

      async.each(results, function(result, callback) {
        waitForLog(result.uniqueQueryId, function(error, response, hit, record) {
          should.not.exist(error);
          itLogsBaseFields(record, result.uniqueQueryId, this.user);
          callback();
        }.bind(this));
      }.bind(this), done);
    }.bind(this));
  });

  it('logs requests that time out before responding', function(done) {
    this.timeout(90000);
    request.get('http://localhost:9080/delay/65000', this.options, function(error, response) {
      response.statusCode.should.eql(504);

      waitForLog(this.uniqueQueryId, { wait: 10000 }, function(error, response, hit, record) {
        should.not.exist(error);
        record.response_status.should.eql(504);
        itLogsBaseFields(record, this.uniqueQueryId, this.user);
        itLogsBackendFields(record);
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs requests that are canceled before completing', function(done) {
    this.timeout(4500);
    var options = _.merge({}, this.options, {
      timeout: 500,
    });

    request.get('http://localhost:9080/delay/2000', options, function() {
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.response_status.should.eql(499);
        itLogsBaseFields(record, this.uniqueQueryId, this.user);
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs requests that are cached', function(done) {
    this.timeout(10000);

    async.timesSeries(3, function(index, callback) {
      request.get('http://localhost:9080/cacheable-expires/test', this.options, function(error) {
        setTimeout(function() {
          callback(error);
        }, 1050);
      });
    }.bind(this), function() {
      waitForLog(this.uniqueQueryId, { minCount: 3 }, function(error, response) {
        should.not.exist(error);

        var cachedHits = 0;
        async.eachSeries(response.hits.hits, function(hit, callback) {
          var record = hit._source;
          record.response_status.should.eql(200);
          record.response_age.should.be.a('number');
          if(record.response_age >= 1) {
            cachedHits++;
          }
          itLogsBaseFields(record, this.uniqueQueryId, this.user);
          callback();
        }.bind(this), function() {
          cachedHits.should.eql(2);
          done();
        });
      }.bind(this));
    }.bind(this), done);
  });

  it('logs requests denied by the gatekeeper', function(done) {
    this.timeout(4500);
    var options = _.merge({}, this.options, {
      headers: {
        'X-Api-Key': 'INVALID_KEY',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      response.statusCode.should.eql(403);

      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.response_status.should.eql(403);
        itLogsBaseFields(record, this.uniqueQueryId);
        record.api_key.should.eql('INVALID_KEY');
        record.gatekeeper_denied_code.should.eql('api_key_invalid');
        should.not.exist(record.user_email);
        should.not.exist(record.user_id);
        should.not.exist(record.user_registration_source);

        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs requests when the api backend is down', function(done) {
    this.timeout(4500);
    request.get('http://localhost:9080/down', this.options, function(error, response) {
      response.statusCode.should.eql(502);

      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.response_status.should.eql(502);
        itLogsBaseFields(record, this.uniqueQueryId, this.user);
        itLogsBackendFields(record);
        done();
      }.bind(this));
    }.bind(this));
  });

  describe('when gatekeeper is down', function() {
    before(function stopGatekeeper(done) {
      this.timeout(20000);
      var configPath = processEnv.supervisordConfigPath();
      var execOpts = {
        env: processEnv.env(),
      };

      execFile('supervisorctl', ['-c', configPath, 'stop', 'gatekeeper:*'], execOpts, function(error, stdout, stderr) {
        if(error) {
          return done('could not stop gatkeeper processes: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr);
        }

        done();
      });
    });

    after(function restartGatekeeper(done) {
      this.timeout(20000);
      var configPath = processEnv.supervisordConfigPath();
      var execOpts = {
        env: processEnv.env(),
      };

      execFile('supervisorctl', ['-c', configPath, 'start', 'gatekeeper:*'], execOpts, function(error, stdout, stderr) {
        if(error) {
          return done('could not start gatkeeper processes: ' + error.message + '\n\nSTDOUT: ' + stdout + '\n\nSTDERR:' + stderr);
        }

        done();
      });
    });

    it('still logs failed requests', function(done) {
      this.timeout(4500);
      request.get('http://localhost:9080/info/', this.options, function(error, response) {
        response.statusCode.should.eql(502);

        waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
          should.not.exist(error);
          record.response_status.should.eql(502);
          itLogsBaseFields(record, this.uniqueQueryId, this.user);
          itDoesNotLogBackendFields(record);
          done();
        }.bind(this));
      }.bind(this));
    });
  });
});
