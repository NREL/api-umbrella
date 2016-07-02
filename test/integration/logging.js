'use strict';

require('../test_helper');

var _ = require('lodash'),
    async = require('async'),
    config = require('../support/config'),
    Curler = require('curler').Curler,
    crypto = require('crypto'),
    Factory = require('factory-lady'),
    mongoose = require('mongoose'),
    randomstring = require('randomstring'),
    request = require('request');

describe('logging', function() {
  shared.runServer({
    apis: [
      {
        _id: 'down',
        frontend_host: 'localhost',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9450,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/down',
            backend_prefix: '/down',
          },
        ],
      },
      {
        _id: 'wildcard-frontend-host',
        frontend_host: '*',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9444,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/wildcard-info/',
            backend_prefix: '/info/',
          },
        ],
      },
      {
        _id: 'example',
        frontend_host: '*',
        backend_host: 'localhost',
        servers: [
          {
            host: '127.0.0.1',
            port: 9444,
          },
        ],
        url_matches: [
          {
            frontend_prefix: '/',
            backend_prefix: '/',
          },
        ],
      },
    ],
  });

  function generateUniqueQueryId() {
    return process.hrtime().join('-') + '-' + Math.random();
  }

  beforeEach(function createUser(done) {
    this.uniqueQueryId = generateUniqueQueryId();
    Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
      this.user = user;
      this.apiKey = user.api_key;
      this.options = {
        headers: {
          'X-Api-Key': this.apiKey,
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

    if(!uniqueQueryId) {
      return done('waitForLog must be passed a uniqueQueryId parameter. Passed: ' + uniqueQueryId);
    }

    options = options || {};
    options.timeout = options.timeout || 8500;
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
        return done((new Date()) + ': Timed out fetching log for request_query.unique_query_id:' + uniqueQueryId);
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
    record.request_at.should.match(/^\d{13}$/);
    record.request_hierarchy.should.be.an('array');
    record.request_hierarchy.length.should.be.gte(1);
    record.request_host.should.eql('localhost:9080');
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
    record.internal_gatekeeper_time.should.be.a('number');
    record.proxy_overhead.should.be.a('number');

    if(user) {
      record.api_key.should.eql(user.api_key);
      record.user_email.should.eql(user.email);
      record.user_id.should.eql(user.id);
      record.user_registration_source.should.eql('web');
    }
  }

  function itLogsBackendFields(record) {
    record.backend_response_time.should.be.a('number');
  }

  function itDoesNotLogBackendFields(record) {
    should.not.exist(record.backend_response_time);
  }

  it('logs all the expected response fileds (for a non-chunked, non-gzipped response)', function(done) {
    this.timeout(10000);
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

    var url1 = 'http%3A%2F%2Fexample.com%2F%3Ffoo%3Dbar%26foo%3Dbar%20more+stuff';
    var url2 = '%ED%A1%BC';
    var url3Prefix = 'https%3A//example.com/foo/';
    var url3InvalidSuffix = '%D6%D0%B9%FA%BD%AD%CB%D5%CA%A1%B8%D3%D3%DC%CF%D8%D2%BB%C2%A5%C5%CC%CA%C0%BD%F5%BB%AA%B3%C7200%D3%E0%D2%B5%D6%F7%B9%BA%C2%F2%B5%C4%C9%CC%C6%B7%B7%BF%A3%AC%D2%F2%BF%AA%B7%A2%C9%CC%C5%DC%C2%B7%D2%D1%CD%A3%B9%A420%B8%F6%D4%C2%A3%AC%D2%B5%D6%F7%C4%C3%B7%BF%CE%DE%CD%FB%C8%B4%D0%E8%BC%CC%D0%F8%B3%A5%BB%B9%D2%F8%D0%D0%B4%FB%BF%EE%A1%A3%CF%F2%CA%A1%CA%D0%CF%D8%B9%FA%BC%D2%D0%C5%B7%C3%BE%D6%B7%B4%D3%B3%BD%FC2%C4%EA%CE%DE%C8%CB%B4%A6%C0%ED%A1%A3%D4%DA%B4%CB%B0%B8%D6%D0%A3%AC%CE%D2%C3%C7%BB%B3%D2%C9%D3%D0%C8%CB%CA%A7%D6%B0%E4%C2%D6%B0/sites/default/files/googleanalytics/ga.js';
    var url3 = url3Prefix + url3InvalidSuffix;

    var requestUrl = 'http://localhost:9080/logging-example/foo/bar/?unique_query_id=' + this.uniqueQueryId + '&url1=' + url1 + '&url2=' + url2 + '&url3=' + url3;
    request.get(requestUrl, options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);

      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        var fields = _.keys(record).sort();

        fields.should.eql([
          'api_key',
          'backend_response_time',
          'gatekeeper_denied_code',
          'internal_gatekeeper_time',
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
          'request_ip_city',
          'request_ip_country',
          'request_ip_location',
          'request_ip_region',
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
          'response_cache',
          'response_content_encoding',
          'response_content_length',
          'response_content_type',
          'response_server',
          'response_size',
          'response_status',
          'response_time',
          'response_transfer_encoding',
          'user_email',
          'user_id',
          'user_registration_source',
        ]);

        record.api_key.should.eql(this.apiKey);
        record.backend_response_time.should.be.a('number');
        record.internal_gatekeeper_time.should.be.a('number');
        record.proxy_overhead.should.be.a('number');
        record.request_accept.should.eql('text/plain; q=0.5, text/html');
        record.request_accept_encoding.should.eql('compress, gzip');
        record.request_at.should.match(/^\d{13}$/);
        record.request_basic_auth_username.should.eql('basic-auth-username-example');
        record.request_connection.should.eql('close');
        record.request_content_type.should.eql('application/x-www-form-urlencoded');
        record.request_hierarchy.should.eql([
          '0/localhost:9080/',
          '1/localhost:9080/logging-example/',
          '2/localhost:9080/logging-example/foo/',
          '3/localhost:9080/logging-example/foo/bar',
        ]);
        record.request_host.should.eql('localhost:9080');
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
        record.request_query.url1.should.eql(decodeURIComponent(url1).replace('+', ' '));
        record.request_query.url2.should.eql(url2);
        record.request_query.url3.should.eql(decodeURIComponent(url3Prefix) + url3InvalidSuffix);
        record.request_referer.should.eql('http://example.com');
        record.request_scheme.should.eql('http');
        record.request_size.should.be.a('number');
        record.request_url.should.eql(requestUrl);
        record.request_user_agent.should.eql('curl/7.37.1');
        record.request_user_agent_family.should.eql('cURL');
        record.request_user_agent_type.should.eql('Library');
        // The age might be 1 second higher than the original response if the
        // response happens right on the boundary of a second.
        record.response_age.should.be.gte(20);
        record.response_age.should.be.lte(21);
        record.response_cache.should.eql('MISS');
        record.response_content_type.should.eql('text/plain; charset=utf-8');
        record.response_server.should.eql('openresty');
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
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      gzip: true,
    });

    request.get('http://localhost:9080/compressible-delayed-chunked/5', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);

      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.response_content_encoding.should.eql('gzip');
        record.response_transfer_encoding.should.eql('chunked');

        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs the geocoded ip related fields for ipv4 address', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'X-Forwarded-For': '8.8.8.8',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_ip.should.eql('8.8.8.8');
        record.request_ip_country.should.eql('US');
        record.request_ip_region.should.eql('CA');
        record.request_ip_city.should.eql('Mountain View');
        Object.keys(record.request_ip_location).length.should.eql(2);
        record.request_ip_location.lat.should.be.closeTo(37.386, 0.00);
        record.request_ip_location.lon.should.be.closeTo(-122.0838, 0.00);

        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs the geocoded ip related fields for ipv6 address', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'X-Forwarded-For': '2001:4860:4860::8888',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_ip.should.eql('2001:4860:4860::8888');
        record.request_ip_country.should.eql('US');
        should.not.exist(record.request_ip_region);
        should.not.exist(record.request_ip_city);
        Object.keys(record.request_ip_location).length.should.eql(2);
        record.request_ip_location.lat.should.be.closeTo(37.751, 0.00);
        record.request_ip_location.lon.should.be.closeTo(-97.822, 0.00);

        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs the geocoded ip related fields for ipv4 mapped ipv6 address', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'X-Forwarded-For': '0:0:0:0:0:ffff:808:808',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_ip.should.eql('::ffff:8.8.8.8');
        record.request_ip_country.should.eql('US');
        record.request_ip_region.should.eql('CA');
        record.request_ip_city.should.eql('Mountain View');
        Object.keys(record.request_ip_location).length.should.eql(2);
        record.request_ip_location.lat.should.be.closeTo(37.386, 0.00);
        record.request_ip_location.lon.should.be.closeTo(-122.0838, 0.00);

        done();
      }.bind(this));
    }.bind(this));
  });

  it('stores the most recently seen geocode for city in a separate index', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'X-Forwarded-For': '8.8.8.8',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error) {
        should.not.exist(error);
        var id = crypto.createHash('sha256').update('US-CA-Mountain View').digest('hex');
        mongoose.testConnection.model('LogCityLocation').find({
          _id: id,
        }, function(error, locations) {
          should.not.exist(error);
          locations.length.should.eql(1);
          var location = locations[0].toObject();
          location.updated_at.should.be.a('date');
          location.location.type.should.eql('Point');
          location.location.coordinates.length.should.eql(2);
          location.location.coordinates[0].should.be.closeTo(-122.0838, 0.00);
          location.location.coordinates[1].should.be.closeTo(37.386, 0.00);
          _.omit(location, 'updated_at', 'location').should.eql({
            _id: id,
            country: 'US',
            region: 'CA',
            city: 'Mountain View',
          });
          done();
        });
      }.bind(this));
    }.bind(this));
  });

  it('logs request and caches locations where geocoding returns a city and country, but no region', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'X-Forwarded-For': '42.61.81.163',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_ip.should.eql('42.61.81.163');
        record.request_ip_country.should.eql('SG');
        should.not.exist(record.request_ip_region);
        record.request_ip_city.should.eql('Singapore');
        Object.keys(record.request_ip_location).length.should.eql(2);
        record.request_ip_location.lat.should.be.closeTo(1.2931, 0.00);
        record.request_ip_location.lon.should.be.closeTo(103.8558, 0.00);

        var id = crypto.createHash('sha256').update('SG--Singapore').digest('hex');
        mongoose.testConnection.model('LogCityLocation').find({
          _id: id,
        }, function(error, locations) {
          should.not.exist(error);
          locations.length.should.eql(1);
          var location = locations[0].toObject();
          location.updated_at.should.be.a('date');
          location.location.type.should.eql('Point');
          location.location.coordinates.length.should.eql(2);
          location.location.coordinates[0].should.be.closeTo(103.8558, 0.00);
          location.location.coordinates[1].should.be.closeTo(1.2931, 0.00);
          _.omit(location, 'updated_at', 'location').should.eql({
            _id: id,
            country: 'SG',
            city: 'Singapore',
          });
          done();
        });
      }.bind(this));
    }.bind(this));
  });

  it('logs request and caches locations where geocoding returns a country, but no city or region', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'X-Forwarded-For': '182.50.152.193',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_ip.should.eql('182.50.152.193');
        record.request_ip_country.should.eql('SG');
        should.not.exist(record.request_ip_region);
        should.not.exist(record.request_ip_city);
        Object.keys(record.request_ip_location).length.should.eql(2);
        record.request_ip_location.lat.should.be.closeTo(1.3667, 0.00);
        record.request_ip_location.lon.should.be.closeTo(103.8, 0.00);

        var id = crypto.createHash('sha256').update('SG--').digest('hex');
        mongoose.testConnection.model('LogCityLocation').find({
          _id: id,
        }, function(error, locations) {
          should.not.exist(error);
          locations.length.should.eql(1);
          var location = locations[0].toObject();
          location.updated_at.should.be.a('date');
          location.location.type.should.eql('Point');
          location.location.coordinates.length.should.eql(2);
          location.location.coordinates[0].should.be.closeTo(103.8, 0.00);
          location.location.coordinates[1].should.be.closeTo(1.3667, 0.00);
          _.omit(location, 'updated_at', 'location').should.eql({
            _id: id,
            country: 'SG',
          });
          done();
        });
      }.bind(this));
    }.bind(this));
  });

  it('logs requests and caches city when geocoding returns a city with accent characters', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'X-Forwarded-For': '191.102.110.22',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_ip.should.eql('191.102.110.22');
        record.request_ip_country.should.eql('CO');
        record.request_ip_region.should.eql('34');
        record.request_ip_city.should.eql('Bogotá');
        Object.keys(record.request_ip_location).length.should.eql(2);
        record.request_ip_location.lat.should.be.closeTo(4.6492, 0.00);
        record.request_ip_location.lon.should.be.closeTo(-74.0628, 0.00);

        var id = crypto.createHash('sha256').update('CO-34-Bogotá', 'utf8').digest('hex');
        mongoose.testConnection.model('LogCityLocation').find({
          _id: id,
        }, function(error, locations) {
          should.not.exist(error);
          locations.length.should.eql(1);
          var location = locations[0].toObject();
          location.updated_at.should.be.a('date');
          location.location.type.should.eql('Point');
          location.location.coordinates.length.should.eql(2);
          location.location.coordinates[0].should.be.closeTo(-74.0628, 0.00);
          location.location.coordinates[1].should.be.closeTo(4.6492, 0.00);
          _.omit(location, 'updated_at', 'location').should.eql({
            _id: id,
            country: 'CO',
            region: '34',
            city: 'Bogotá',
          });
          done();
        });
      }.bind(this));
    }.bind(this));
  });

  it('logs the accept-encoding header prior to normalization', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'Accept-Encoding': 'compress, gzip',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_accept_encoding.should.eql('compress, gzip');
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs the external connection header and not the one used internally', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'Connection': 'close',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_connection.should.eql('close');
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs the host used to access the site for a wildcard api', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'Host': 'unknown.foo',
      },
    });

    request.get('http://localhost:9080/wildcard-info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_host.should.eql('unknown.foo');
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs request scheme when hit directly', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      strictSSL: false,
    });

    request.get('https://localhost:9081/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_scheme.should.eql('https');
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs request scheme when forwarded from an external load balancer via X-Forwarded-Proto', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'X-Forwarded-Proto': 'https',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_scheme.should.eql('https');
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs headers that contain quotes (to account for json escaping in nginx logs)', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'Referer': 'http://example.com/"foo\'bar',
        'Content-Type': 'text"\x22plain\'\\x22',
      },
      auth: {
        user: '"foo\'bar',
        pass: 'bar"foo\'',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_referer.should.eql('http://example.com/"foo\'bar');
        record.request_content_type.should.eql('text""plain\'\\x22');
        record.request_basic_auth_username.should.eql('"foo\'bar');
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs headers that contain special characters', function(done) {
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'Referer': 'http://example.com/!\\*^%#[]',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_referer.should.eql('http://example.com/!\\*^%#[]');
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs requests with utf8 characters in the URL', function(done) {
    this.timeout(10000);

    // Use curl and not request for these tests, since the request library
    // calls url.parse which has a bug that causes backslashes to become
    // forward slashes https://github.com/joyent/node/pull/8459
    var curl = new Curler();
    var args = 'utf8=✓&utf8_url_encoded=%E2%9C%93&more_utf8=¬¶ªþ¤l&more_utf8_hex=\xAC\xB6\xAA\xFE\xA4l&more_utf8_hex_lowercase=\xac\xb6\xaa\xfe\xa4l&actual_backslash_x=\\xAC\\xB6\\xAA\\xFE\\xA4l';
    curl.request({
      method: 'GET',
      url: 'http://localhost:9080/info/utf8/✓/encoded_utf8/%E2%9C%93/?api_key=' + this.apiKey + '&unique_query_id=' + this.uniqueQueryId + '&' + args,
    }, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_query.utf8.should.eql('%E2%9C%93');
        record.request_query.utf8_url_encoded.should.eql('%E2%9C%93');
        record.request_query.more_utf8.should.eql('%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l');
        record.request_query.more_utf8_hex.should.eql('%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l');
        record.request_query.more_utf8_hex_lowercase.should.eql('%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l');
        record.request_query.actual_backslash_x.should.eql('\\xAC\\xB6\\xAA\\xFE\\xA4l');
        record.request_path.should.eql('/info/utf8/%E2%9C%93/encoded_utf8/%E2%9C%93/');
        record.request_url.should.contain(record.request_path);
        record.request_url.should.endWith('&utf8=%E2%9C%93&utf8_url_encoded=%E2%9C%93&more_utf8=%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l&more_utf8_hex=%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l&more_utf8_hex_lowercase=%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l&actual_backslash_x=\\xAC\\xB6\\xAA\\xFE\\xA4l');
        done();
      });
    }.bind(this));
  });

  it('url encodes valid utf8 characters in the URL path, URL query string, and HTTP headers', function(done) {
    this.timeout(10000);

    // Testing various encodings of the UTF-8 pound symbol: £
    var urlEncoded = '%C2%A3';
    var base64ed = 'wqM=';
    var raw = new Buffer(base64ed, 'base64').toString();

    // When in the URL path or query string, we expect the raw £ symbol to be
    // logged as the url encoded version.
    var expectedRawUrlEncoded = urlEncoded;

    var args = 'url_encoded=' + urlEncoded + '&base64ed=' + base64ed + '&raw=' + raw;
    request({
      method: 'GET',
      url: 'http://localhost:9080/info/' + urlEncoded + '/' + base64ed + '/' + raw + '/?api_key=' + this.apiKey + '&unique_query_id=' + this.uniqueQueryId + '&' + args,
      headers: {
        'Content-Type': urlEncoded,
        'Referer': base64ed,
        'Origin': raw,
      },
    }, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);

        // URL query string
        record.request_query.url_encoded.should.eql(urlEncoded);
        record.request_query.base64ed.should.eql(base64ed);
        record.request_query.raw.should.eql(expectedRawUrlEncoded);

        // URL path
        record.request_path.should.eql('/info/' + urlEncoded + '/' + base64ed + '/' + expectedRawUrlEncoded + '/');
        record.request_hierarchy.should.eql([
          '0/localhost:9080/',
          '1/localhost:9080/info/',
          '2/localhost:9080/info/' + urlEncoded + '/',
          '3/localhost:9080/info/' + urlEncoded + '/' + base64ed + '/',
          '4/localhost:9080/info/' + urlEncoded + '/' + base64ed + '/' + expectedRawUrlEncoded,
        ]);

        // Full URL
        record.request_url.should.contain(record.request_path);
        record.request_url.should.endWith('url_encoded=' + urlEncoded + '&base64ed=' + base64ed + '&raw=' + expectedRawUrlEncoded);

        // HTTP headers
        record.request_content_type.should.eql(urlEncoded);
        record.request_referer.should.eql(base64ed);
        record.request_origin.should.eql(raw);

        done();
      });
    }.bind(this));
  });

  it('url encodes invalid utf8 characters in the URL path, URL query string, and HTTP headers', function(done) {
    this.timeout(10000);

    // Testing various encodings of the ISO-8859-1 pound symbol: £ (but since
    // this is the ISO-8859-1 version, it's not valid UTF-8).
    var urlEncoded = '%A3';
    var base64ed = 'ow==';
    var raw = new Buffer(base64ed, 'base64').toString();

    // Since the encoding of this string wasn't actually a valid UTF-8 string,
    // we expect it to get logged as the UTF-8 replacement character.
    var expectedRawUrlEncoded = '%EF%BF%BD';
    var expectedRawBinary = new Buffer('77+9', 'base64').toString();

    var args = 'url_encoded=' + urlEncoded + '&base64ed=' + base64ed + '&raw=' + raw;

    // Use curl and not request for this test, since node's HTTP parser
    // prevents invalid utf8 characters from being used in headers as of NodeJS
    // v0.10.42. But we still want to test this, since other clients can still
    // pass invalid utf8 characters.
    var curl = new Curler();
    curl.request({
      method: 'GET',
      url: 'http://localhost:9080/info/' + urlEncoded + '/' + base64ed + '/' + raw + '/?api_key=' + this.apiKey + '&unique_query_id=' + this.uniqueQueryId + '&' + args,
      headers: {
        'Content-Type': urlEncoded,
        'Referer': base64ed,
        'Origin': raw,
      },
    }, function(error) {
      should.not.exist(error);
      // Don't require 200 response. The express.js backend app seems to fail
      // when processing some of these special characters in the path, but we
      // don't really care for these logging purposes.
      // response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);

        // URL query string
        record.request_query.url_encoded.should.eql(urlEncoded);
        record.request_query.base64ed.should.eql(base64ed);
        record.request_query.raw.should.eql(expectedRawUrlEncoded);

        // URL path
        record.request_path.should.eql('/info/' + urlEncoded + '/' + base64ed + '/' + expectedRawUrlEncoded + '/');
        record.request_hierarchy.should.eql([
          '0/localhost:9080/',
          '1/localhost:9080/info/',
          '2/localhost:9080/info/' + urlEncoded + '/',
          '3/localhost:9080/info/' + urlEncoded + '/' + base64ed + '/',
          '4/localhost:9080/info/' + urlEncoded + '/' + base64ed + '/' + expectedRawUrlEncoded,
        ]);

        // Full URL
        record.request_url.should.contain(record.request_path);
        record.request_url.should.endWith('url_encoded=' + urlEncoded + '&base64ed=' + base64ed + '&raw=' + expectedRawUrlEncoded);

        // HTTP headers
        record.request_content_type.should.eql(urlEncoded);
        record.request_referer.should.eql(base64ed);
        record.request_origin.should.eql(expectedRawBinary);

        done();
      });
    }.bind(this));
  });

  it('decodes url escape sequences for the request_query, but not in the complete URL, path, or headers', function(done) {
    this.timeout(10000);

    var urlEncoded = 'http%3A%2F%2Fexample.com%2Fsub%2Fsub%2F%3Ffoo%3Dbar%26foo%3Dbar%20more+stuff';
    var urlDecoded = decodeURIComponent(urlEncoded).replace('+', ' '); // nginx also decodes + as spaces

    var args = 'url_encoded=' + urlEncoded;
    request({
      method: 'GET',
      url: 'http://localhost:9080/info/' + urlEncoded + '/?api_key=' + this.apiKey + '&unique_query_id=' + this.uniqueQueryId + '&' + args,
      headers: {
        'Content-Type': urlEncoded,
      },
    }, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);

        // URL query string
        record.request_query.url_encoded.should.eql(urlDecoded);

        // URL path
        record.request_path.should.eql('/info/' + urlEncoded + '/');
        record.request_hierarchy.should.eql([
          '0/localhost:9080/',
          '1/localhost:9080/info/',
          '2/localhost:9080/info/' + urlEncoded,
        ]);

        // Full URL
        record.request_url.should.contain(record.request_path);
        record.request_url.should.endWith('url_encoded=' + urlEncoded);

        // HTTP headers
        record.request_content_type.should.eql(urlEncoded);

        done();
      });
    }.bind(this));
  });

  it('logs optionally url encodable ascii strings as given (except in request_query where they are decoded)', function(done) {
    this.timeout(10000);

    var asIs = '-%2D ;%3B +%2B /%2F :%3A 0%30 >%3E {%7B';
    var urlDecoded = decodeURIComponent(asIs).replace('+', ' '); // nginx also decodes + as spaces

    var args = 'as_is=' + asIs;

    // Use curl and not request for these tests, since the request library
    // escapes all spaces as %20, which we want to avoid for this test.
    var curl = new Curler();
    curl.request({
      method: 'GET',
      url: 'http://localhost:9080/info/' + asIs + '/?api_key=' + this.apiKey + '&unique_query_id=' + this.uniqueQueryId + '&' + args,
      headers: {
        'Content-Type': asIs,
      },
    }, function(error) {
      should.not.exist(error);
      // Don't require 200 response. The express.js backend app seems to fail
      // when processing some of these special characters in the path, but we
      // don't really care for these logging purposes.
      // response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);

        // URL query string
        record.request_query.as_is.should.eql(urlDecoded);

        // URL path
        record.request_path.should.eql('/info/' + asIs + '/');
        record.request_hierarchy.should.eql([
          '0/localhost:9080/',
          '1/localhost:9080/info/',
          '2/localhost:9080/info/-%2D ;%3B +%2B /',
          '3/localhost:9080/info/-%2D ;%3B +%2B /%2F :%3A 0%30 >%3E {%7B',
        ]);

        // Full URL
        record.request_url.should.contain(record.request_path);
        record.request_url.should.endWith('as_is=' + asIs);

        // HTTP headers
        record.request_content_type.should.eql(asIs);

        done();
      });
    }.bind(this));
  });

  it('logs requests with backslashes and slashes', function(done) {
    this.timeout(10000);

    // Use curl and not request for these tests, since the request library
    // calls url.parse which has a bug that causes backslashes to become
    // forward slashes https://github.com/joyent/node/pull/8459
    var curl = new Curler();
    curl.request({
      method: 'GET',
      url: 'http://localhost:9080/info/extra//slash/some\\backslash/encoded%5Cbackslash/encoded%2Fslash?api_key=' + this.apiKey + '&unique_query_id=' + this.uniqueQueryId + '&forward_slash=/slash&encoded_forward_slash=%2F&back_slash=\\&encoded_back_slash=%5C',
    }, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_query.forward_slash.should.eql('/slash');
        record.request_query.encoded_forward_slash.should.eql('/');
        record.request_query.back_slash.should.eql('\\');
        record.request_query.encoded_back_slash.should.eql('\\');
        record.request_path.should.eql('/info/extra//slash/some\\backslash/encoded%5Cbackslash/encoded%2Fslash');
        record.request_url.should.contain(record.request_path);
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs requests with dots in query parameters by translating dots to underscores (elasticsearch 2 compatibility)', function(done) {
    this.timeout(10000);

    var options = _.merge({}, this.options, {
      qs: {
        'foo.bar.baz': 'example.1',
        'foo.bar': 'example.2',
        'foo[bar]': 'example.3',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);
      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_query.foo_bar_baz.should.eql('example.1');
        record.request_query.foo_bar.should.eql('example.2');
        record.request_query['foo[bar]'].should.eql('example.3');
        done();
      }.bind(this));
    }.bind(this));
  });

  describe('multiple request header handling', function() {
    var multipleForbidden = {
      'Content-Type': 'request_content_type',
      'Referer': 'request_referer',
      'User-Agent': 'request_user_agent',

      // These headers should technically be tested too, but they're difficult
      // to test since HTTP clients and servers don't want to set multiple
      // values. So for now, we'll assume these are being properly handled in
      // src/api-umbrella/utils/flatten_headers.lua.
      //
      // 'Authorization': 'request_basic_auth_username',
      // 'Host': 'request_host',
    };

    var multipleAllowed = {
      'Accept': 'request_accept',
      'Accept-Encoding': 'request_accept_encoding',
      'Connection': 'request_connection',
      'Origin': 'request_origin',
    };

    _.each(multipleForbidden, function(logField, header) {
      it('logs only the first header for ' + header, function(done) {
        this.timeout(10000);

        var options = _.merge({}, this.options);
        options.qs['header'] = header;
        options.headers[header] = ['11', '22'];

        request.get('http://localhost:9080/logging-multiple-request-headers/', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);

          waitForLog(options.qs.unique_query_id, function(error, response, hit, record) {
            should.not.exist(error);
            record[logField].toString().should.eql('11');
            done();
          });
        });
      });
    });

    _.each(multipleAllowed, function(logField, header) {
      it('logs all headers (comma delimited) ' + header, function(done) {
        this.timeout(10000);

        var options = _.merge({}, this.options);
        options.qs['header'] = header;
        options.headers[header] = ['11', '22'];

        request.get('http://localhost:9080/logging-multiple-request-headers/', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);

          waitForLog(options.qs.unique_query_id, function(error, response, hit, record) {
            should.not.exist(error);
            record[logField].toString().should.eql('11, 22');
            done();
          });
        });
      });
    });
  });

  describe('multiple response header handling', function() {
    var multipleForbidden = {
      'Age': 'response_age',

      // These headers should technically be tested too, but they're difficult
      // to test since HTTP clients and servers don't want to set multiple
      // values. So for now, we'll assume these are being properly handled in
      // src/api-umbrella/utils/flatten_headers.lua.
      //
      // 'Content-Length': 'response_content_length',
      // 'Content-Type': 'response_content_type',
    };

    var multipleAllowed = {
      'X-Cache': 'response_cache',

      // These headers should technically be tested too, but they're difficult
      // to test since HTTP clients and servers don't want to set multiple
      // values. So for now, we'll assume these are being properly handled in
      // src/api-umbrella/utils/flatten_headers.lua.
      //
      // 'Content-Encoding': 'response_content_encoding',
      // 'Transfer-Encoding': 'response_transfer_encoding',
    };

    _.each(multipleForbidden, function(logField, header) {
      it('logs only the first header for ' + header, function(done) {
        this.timeout(10000);

        var options = _.merge({}, this.options);
        options.qs['header'] = header;

        request.get('http://localhost:9080/logging-multiple-response-headers/', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);

          waitForLog(options.qs.unique_query_id, function(error, response, hit, record) {
            should.not.exist(error);
            record[logField].toString().should.eql('11');
            done();
          });
        });
      });
    });

    _.each(multipleAllowed, function(logField, header) {
      it('logs all headers (comma delimited) ' + header, function(done) {
        this.timeout(10000);

        var options = _.merge({}, this.options);
        options.qs['header'] = header;

        request.get('http://localhost:9080/logging-multiple-response-headers/', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);

          waitForLog(options.qs.unique_query_id, function(error, response, hit, record) {
            should.not.exist(error);
            record[logField].toString().should.eql('11, 22');
            done();
          });
        });
      });
    });
  });

  it('logs the request_at field as a date', function(done) {
    this.timeout(10000);

    request.get('http://localhost:9080/info/', this.options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);

      waitForLog(this.options.qs.unique_query_id, function(error, response, hit) {
        should.not.exist(error);

        global.elasticsearch.indices.getMapping({
          index: hit['_index'],
          type: hit['_type'],
          field: 'request_at',
        }, function(error, res) {
          should.not.exist(error);

          var property = res[hit['_index']].mappings[hit['_type']].properties.request_at;
          if(config.get('elasticsearch.api_version') === 1) {
            property.should.eql({
              type: 'date',
              format: 'dateOptionalTime',
            });
          } else if(config.get('elasticsearch.api_version') >= 2) {
            property.should.eql({
              type: 'date',
              format: 'strict_date_optional_time||epoch_millis',
            });
          } else {
            throw 'Unknown elasticsearch version: ' + config.get('elasticsearch.api_version');
          }

          done();
        });
      });
    }.bind(this));
  });

  it('logs the request_at as the time the request finishes (not when it begins)', function(done) {
    this.timeout(15000);

    var requestStart = Date.now();
    request.get('http://localhost:9080/delay/3000', this.options, function(error, response) {
      var requestEnd = Date.now();
      should.not.exist(error);
      response.statusCode.should.eql(200);

      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);

        var recordResponseTime = record.response_time;
        recordResponseTime.should.be.gte(2500);
        recordResponseTime.should.be.lte(3500);

        var localResponseTime = requestEnd - requestStart;
        localResponseTime.should.be.gte(2500);
        localResponseTime.should.be.lte(3500);

        var diffExpectedEndTime = requestEnd - record.request_at;
        diffExpectedEndTime.should.be.gte(-500);
        diffExpectedEndTime.should.be.lte(500);

        done();
      });
    }.bind(this));
  });


  it('successfully logs query strings when the field first indexed was a date, but later queries are not (does not attempt to map fields into dates)', function(done) {
    this.timeout(30000);

    var options = _.merge({}, this.options, {
      qs: {
        'unique_query_id': generateUniqueQueryId(),
        'date_field': '2010-05-01',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);

      waitForLog(options.qs.unique_query_id, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_query.date_field.should.eql('2010-05-01');

        options.qs.unique_query_id = generateUniqueQueryId();
        options.qs.date_field = '2010-05-0';
        request.get('http://localhost:9080/info/', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);

          waitForLog(options.qs.unique_query_id, function(error, response, hit, record) {
            should.not.exist(error);
            record.request_query.date_field.should.eql('2010-05-0');

            options.qs.unique_query_id = generateUniqueQueryId();
            options.qs.date_field = 'foo';
            request.get('http://localhost:9080/info/', options, function(error, response) {
              should.not.exist(error);
              response.statusCode.should.eql(200);

              waitForLog(options.qs.unique_query_id, function(error, response, hit, record) {
                should.not.exist(error);
                record.request_query.date_field.should.eql('foo');
                done();
              });
            });
          });
        });
      });
    });
  });

  it('successfully logs query strings when the field first indexed was a number, but later queries are not (does not attempt to map fields into numbers)', function(done) {
    this.timeout(30000);

    var options = _.merge({}, this.options, {
      qs: {
        'unique_query_id': generateUniqueQueryId(),
        'number_field': '123',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(200);

      waitForLog(options.qs.unique_query_id, function(error, response, hit, record) {
        should.not.exist(error);
        record.request_query.number_field.should.eql('123');

        options.qs.unique_query_id = generateUniqueQueryId();
        options.qs.number_field = 'foo';
        request.get('http://localhost:9080/info/', options, function(error, response) {
          should.not.exist(error);
          response.statusCode.should.eql(200);

          waitForLog(options.qs.unique_query_id, function(error, response, hit, record) {
            should.not.exist(error);
            record.request_query.number_field.should.eql('foo');
            done();
          });
        });
      });
    });
  });

  it('logs requests that time out before responding', function(done) {
    this.timeout(30000);
    request.get('http://localhost:9080/delay/' + (config.get('nginx.proxy_connect_timeout') * 1000 + 3000), this.options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(504);

      waitForLog(this.uniqueQueryId, { timeout: 10000 }, function(error, response, hit, record) {
        should.not.exist(error);
        record.response_status.should.eql(504);
        itLogsBaseFields(record, this.uniqueQueryId, this.user);
        record.response_time.should.be.greaterThan(config.get('nginx.proxy_connect_timeout') * 1000 - 2000);
        record.response_time.should.be.lessThan(config.get('nginx.proxy_connect_timeout') * 1000 + 2000);
        done();
      }.bind(this));
    }.bind(this));
  });

  it('logs requests that are canceled before completing', function(done) {
    this.timeout(10000);
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
      request.get('http://localhost:9080/cacheable-expires/test', this.options, callback);
    }.bind(this), function() {
      waitForLog(this.uniqueQueryId, { minCount: 3 }, function(error, response) {
        should.not.exist(error);

        var cachedHits = 0;
        async.eachSeries(response.hits.hits, function(hit, callback) {
          var record = hit._source;
          record.response_status.should.eql(200);
          record.response_age.should.be.a('number');
          if(record.response_cache === 'HIT') {
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
    this.timeout(10000);
    var options = _.merge({}, this.options, {
      headers: {
        'X-Api-Key': 'INVALID_KEY',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response) {
      should.not.exist(error);
      response.statusCode.should.eql(403);

      waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
        should.not.exist(error);
        record.response_status.should.eql(403);
        itLogsBaseFields(record, this.uniqueQueryId);
        itDoesNotLogBackendFields(record);
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
    this.timeout(10000);
    request.get('http://localhost:9080/down', this.options, function(error, response) {
      should.not.exist(error);
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

  describe('length limits', function() {
    it('logs requests with the maximum 8KB URL length', function(done) {
      this.timeout(10000);

      var options = _.merge({}, this.options, {});
      delete options.qs;

      var otherHeaderLineContent = 'GET  HTTP/1.1\r\n';
      var urlPath = '/info/?unique_query_id=' + this.uniqueQueryId + '&long=';
      var longQuery = randomstring.generate(8192 - urlPath.length - otherHeaderLineContent.length);
      urlPath += longQuery;
      var url = 'http://localhost:9080' + urlPath;

      request.get(url, options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
          should.not.exist(error);
          record.request_query.long.should.eql(longQuery);
          done();
        }.bind(this));
      }.bind(this));
    });

    // We may actually want to revisit this behavior and log these requests,
    // but documenting current behavior.
    //
    // In order to log these requests, we'd need to move the log_by_lua_file
    // statement out of the "location" block and into the "http" level. We'd
    // then need to account for certain things in the logging logic that won't
    // be present in these error conditions.
    it('does not log requests that exceed the maximum 8KB URL length limit', function(done) {
      this.timeout(10000);

      var options = _.merge({}, this.options, {});
      delete options.qs;

      var otherHeaderLineContent = 'GET  HTTP/1.1\r\n';
      var urlPath = '/info/?unique_query_id=' + this.uniqueQueryId + '&long=';
      var longQuery = randomstring.generate(8193 - urlPath.length - otherHeaderLineContent.length);
      urlPath += longQuery;
      var url = 'http://localhost:9080' + urlPath;

      request.get(url, options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(414);
        waitForLog(this.uniqueQueryId, function(error) {
          error.should.include('Timed out fetching log');
          done();
        }.bind(this));
      }.bind(this));
    });

    it('logs a request with a combination of a long URL and long header, truncating headers', function(done) {
      this.timeout(10000);

      var options = _.merge({}, this.options, {
        headers: {
          'Accept': randomstring.generate(1000),
          'Accept-Encoding': randomstring.generate(1000),
          'Connection': randomstring.generate(1000),
          'Content-Type': randomstring.generate(1000),
          'Host': randomstring.generate(1000),
          'Origin': randomstring.generate(1000),
          'User-Agent': randomstring.generate(1000),
          'Referer': randomstring.generate(1000),
        },
        auth: {
          user: randomstring.generate(1000),
          pass: randomstring.generate(1000),
        },
      });
      delete options.qs;

      var otherHeaderLineContent = 'GET  HTTP/1.1\r\n';
      var urlPath = '/logging-long-response-headers/?unique_query_id=' + this.uniqueQueryId + '&long=';
      var longQuery = randomstring.generate(8192 - urlPath.length - otherHeaderLineContent.length);
      urlPath += longQuery;
      var url = 'http://localhost:9080' + urlPath;

      request.get(url, options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        waitForLog(this.uniqueQueryId, function(error, response, hit, record) {
          should.not.exist(error);

          // Ensure the full URL got logged.
          record.request_query.long.should.eql(longQuery);

          // Ensure the long header values got truncated so we're not
          // susceptible to exceeding rsyslog's message buffers and we're also
          // not storing an unexpected amount of data for values users can pass in.
          record.request_accept.length.should.eql(200);
          record.request_accept_encoding.length.should.eql(200);
          record.request_connection.length.should.eql(200);
          record.request_content_type.length.should.eql(200);
          record.request_host.length.should.eql(200);
          record.request_origin.length.should.eql(200);
          record.request_user_agent.length.should.eql(400);
          record.request_referer.length.should.eql(200);
          record.response_content_encoding.length.should.eql(200);
          record.response_content_type.length.should.eql(200);

          done();
        }.bind(this));
      }.bind(this));
    });
  });

  describe('global rate limits', function() {
    shared.runServer({
      router: {
        global_rate_limits: {
          ip_connections: 5
        },
      },
    });

    it('logs requests rejected by global rate limits', function(done) {
      this.timeout(10000);

      var uniqueQueryIds = [];
      var actualResponseCodes = [];
      var loggedResponseCodes = [];

      async.series([
        function(next) {
          async.times(8, function(index, callback) {
            var uniqueQueryId = generateUniqueQueryId();
            uniqueQueryIds.push(uniqueQueryId);

            var options = _.merge({}, this.options, {
              qs: {
                'unique_query_id': uniqueQueryId,
              },
            });

            request.get('http://localhost:9080/delay/2000', options, function(error, response) {
              if(!error) {
                actualResponseCodes.push(response.statusCode);
              }

              callback(error);
            });
          }.bind(this), next);
        }.bind(this),
        function(next) {
          async.each(uniqueQueryIds, function(uniqueQueryId, callback) {
            waitForLog(uniqueQueryId, function(error, response, hit, record) {
              if(!error) {
                loggedResponseCodes.push(record.response_status);
              }

              callback(error);
            });
          }, next);
        },
      ], function(error) {
        should.not.exist(error);

        var actualSuccesses = _.filter(actualResponseCodes, function(code) { return code === 200; });
        var actualOverLimits = _.filter(actualResponseCodes, function(code) { return code === 429; });
        var loggedSuccesses = _.filter(loggedResponseCodes, function(code) { return code === 200; });
        var loggedOverLimits = _.filter(loggedResponseCodes, function(code) { return code === 429; });

        actualResponseCodes.length.should.eql(8);
        actualSuccesses.length.should.eql(5);
        actualOverLimits.length.should.eql(3);
        loggedResponseCodes.length.should.eql(8);
        loggedSuccesses.length.should.eql(5);
        loggedOverLimits.length.should.eql(3);

        done();
      });
    });
  });
});
