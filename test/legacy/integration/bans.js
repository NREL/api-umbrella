'use strict';

require('../test_helper');

var _ = require('lodash'),
    Factory = require('factory-lady'),
    request = require('request');

describe('bans', function() {
  shared.runServer({
    ban: {
      response: {
        status_code: 418,
        delay: 1,
        message: 'You\'ve been banned!',
      },
      ips: [
        '7.4.2.2',
        '8.7.1.0/24',
      ],
      user_agents: [
        '~*naughty',
      ],
    },
  });

  beforeEach(function createUser(done) {
    Factory.create('api_user', { settings: { rate_limit_mode: 'unlimited' } }, function(user) {
      this.user = user;
      this.apiKey = user.api_key;
      this.options = {
        headers: {
          'X-Api-Key': this.apiKey,
        },
        agentOptions: {
          maxSockets: 500,
        },
      };

      done();
    }.bind(this));
  });

  it('can ban user agents case-insensitively', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'User-Agent': 'some NaUghtY user_agent',
        'X-Forwarded-For': '1.2.3.4, 4.5.6.7, 10.10.10.11, 10.10.10.10, 192.168.12.0, 192.168.13.255',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response, body) {
      should.not.exist(error);
      response.statusCode.should.not.eql(200);
      body.should.contain('banned');
      done();
    });
  });

  it('bans individual ip addresses', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'X-Forwarded-For': '7.4.2.2',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response, body) {
      should.not.exist(error);
      response.statusCode.should.not.eql(200);
      body.should.contain('banned');

      options.headers['X-Forwarded-For'] = '7.4.2.3';
      request.get('http://localhost:9080/info/', options, function(error, response) {
        should.not.exist(error);
        response.statusCode.should.eql(200);
        done();
      });
    });
  });

  it('bans ip address CIDR ranges', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'X-Forwarded-For': '8.7.1.44',
      },
    });

    request.get('http://localhost:9080/info/', options, function(error, response, body) {
      should.not.exist(error);
      response.statusCode.should.not.eql(200);
      body.should.contain('banned');
      done();
    });
  });

  it('allows the response to be customized', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'X-Forwarded-For': '7.4.2.2',
      },
    });

    var startTime = Date.now();
    request.get('http://localhost:9080/info/', options, function(error, response, body) {
      should.not.exist(error);
      response.statusCode.should.eql(418);
      body.should.eql('You\'ve been banned!\n');
      var duration = Date.now() - startTime;
      duration.should.be.gte(1000 - 10);
      duration.should.be.lessThan(2000);

      done();
    });
  });

  it('bans users from the non-API web page content too', function(done) {
    var options = _.merge({}, this.options, {
      headers: {
        'Host': 'with-apis-and-website.foo',
        'X-Forwarded-For': '7.4.2.2',
      },
    });

    request.get('http://localhost:9080/', options, function(error, response, body) {
      should.not.exist(error);
      response.statusCode.should.not.eql(200);
      body.should.contain('banned');
      done();
    });
  });
});
