'use strict';

require('../test_helper');

describe('ip validation', function() {
  shared.runServer({
    apis: [
      {
        frontend_host: 'localhost',
        backend_host: 'example.com',
        url_matches: [
          {
            frontend_prefix: '/info/',
            backend_prefix: '/info/',
          }
        ],
        settings: {
          allowed_ips: [
            '127.0.0.1/32',
            '10.0.0.0/16',
            '2001:db8::/32',
          ],
        },
        sub_settings: [
          {
            http_method: 'any',
            regex: '^/info/sub',
            settings: {
              allowed_ips: [
                '127.0.0.2/32',
              ],
            },
          },
        ],
      },
      {
        frontend_host: 'localhost',
        backend_host: 'example.com',
        url_matches: [
          {
            frontend_prefix: '/hello/test',
            backend_prefix: '/hello/test',
          }
        ],
        settings: {
          allowed_ips: [],
        },
      },
      {
        frontend_host: 'localhost',
        backend_host: 'example.com',
        url_matches: [
          {
            frontend_prefix: '/',
            backend_prefix: '/',
          }
        ],
      },
    ],
  });

  describe('unauthorized ip', function() {
    shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
      headers: {
        'X-Forwarded-For': '192.168.0.1',
      },
    });
  });

  describe('unauthorized ipv6', function() {
    shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
      headers: {
        'X-Forwarded-For': '2001:db9:1234::1',
      },
    });
  });

  describe('authorized ip based on cidr match', function() {
    shared.itBehavesLikeGatekeeperAllowed('/info/', {
      headers: {
        'X-Forwarded-For': '10.0.10.255',
      },
    });
  });

  describe('unauthorized ip based on cidr match', function() {
    shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
      headers: {
        'X-Forwarded-For': '10.1.10.255',
      },
    });
  });

  describe('authorized ipv6 based on cidr match', function() {
    shared.itBehavesLikeGatekeeperAllowed('/info/', {
      headers: {
        'X-Forwarded-For': '2001:db8:1234::1',
      },
    });
  });

  describe('unauthorized ipv6 based on cidr match', function() {
    shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
      headers: {
        'X-Forwarded-For': '2001:db9:1234::1',
      },
    });
  });

  describe('authorized ip based on exact match', function() {
    shared.itBehavesLikeGatekeeperAllowed('/info/', {
      headers: {
        'X-Forwarded-For': '127.0.0.1',
      },
    });
  });

  describe('unauthorized ip based on exact match', function() {
    shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
      headers: {
        'X-Forwarded-For': '127.0.0.2',
      },
    });
  });

  describe('sub-url with different allowed ips', function() {
    describe('originally authorized ip, but no longer authorized at the sub-url level', function() {
      shared.itBehavesLikeGatekeeperBlocked('/info/sub', 403, 'API_KEY_UNAUTHORIZED', {
        headers: {
          'X-Forwarded-For': '127.0.0.1',
        },
      });
    });

    describe('authorized ip at the sub-url level', function() {
      shared.itBehavesLikeGatekeeperAllowed('/info/sub', {
        headers: {
          'X-Forwarded-For': '127.0.0.2',
        },
      });
    });
  });

  describe('no default ip restrictions', function() {
    shared.itBehavesLikeGatekeeperAllowed('/hello', {
      headers: {
        'X-Forwarded-For': '192.168.1.1',
      },
    });
  });

  describe('no ip restrictions with empty ip list', function() {
    shared.itBehavesLikeGatekeeperAllowed('/hello/test', {
      headers: {
        'X-Forwarded-For': '192.168.1.1',
      },
    });
  });

  describe('user specific ip limitations', function() {
    beforeEach(function(done) {
      Factory.create('api_user', {
        settings: {
          allowed_ips: [
            '10.0.0.0/24',
            '192.168.0.0/16',
          ],
        }
      }, function(user) {
        this.apiKey = user.api_key;
        done();
      }.bind(this));
    });

    describe('authorized if user and api settings both to evaluate true', function() {
      shared.itBehavesLikeGatekeeperAllowed('/info/', {
        headers: {
          'X-Forwarded-For': '10.0.0.20',
        },
      });
    });

    describe('unauthorized if user and api settings don\'t both evaluate true', function() {
      shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
        headers: {
          'X-Forwarded-For': '192.168.0.1',
        },
      });
    });

    describe('authorized if user settings evaluate true and no api settings exist', function() {
      shared.itBehavesLikeGatekeeperAllowed('/hello', {
        headers: {
          'X-Forwarded-For': '192.168.0.1',
        },
      });
    });

    describe('unauthorized if user settings evaluate false and no api settings exist', function() {
      shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
        headers: {
          'X-Forwarded-For': '192.167.0.1',
        },
      });
    });

    describe('no ip restrictions with empty ip list', function() {
      beforeEach(function(done) {
        Factory.create('api_user', {
          settings: {
            allowed_ips: [],
          }
        }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
        headers: {
          'X-Forwarded-For': '172.168.1.1',
        },
      });
    });
  });
});
