'use strict';

require('../test_helper');

describe('referer validation', function() {
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
          allowed_referers: [
            '*.example.com/*',
            'https://google.com/',
          ],
        },
        sub_settings: [
          {
            http_method: 'any',
            regex: '^/info/sub',
            settings: {
              allowed_referers: [
                '*.foobar.com/*',
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
          allowed_referers: [],
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

  describe('unauthorized referer', function() {
    shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
      headers: {
        'Referer': 'http://www.foobar.com/',
      },
    });
  });

  describe('authorized referer based on wildcard match', function() {
    shared.itBehavesLikeGatekeeperAllowed('/info/', {
      headers: {
        'Referer': 'http://www.example.com/testing',
      },
    });
  });

  describe('unauthorized referer based on wildcard match', function() {
    shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
      headers: {
        'Referer': 'http://example.com/testing',
      },
    });
  });

  describe('authorized referer based on exact match', function() {
    shared.itBehavesLikeGatekeeperAllowed('/info/', {
      headers: {
        'Referer': 'https://google.com/',
      },
    });
  });

  describe('unauthorized referer based on exact match', function() {
    shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
      headers: {
        'Referer': 'https://google.com/extra',
      },
    });
  });

  describe('sub-url with different allowed referrers', function() {
    describe('originally authorized referer, but no longer authorized at the sub-url level', function() {
      shared.itBehavesLikeGatekeeperBlocked('/info/sub', 403, 'API_KEY_UNAUTHORIZED', {
        headers: {
          'Referer': 'http://www.example.com/testing',
        },
      });
    });

    describe('authorized referer at the sub-url level', function() {
      shared.itBehavesLikeGatekeeperAllowed('/info/sub', {
        headers: {
          'Referer': 'http://www.foobar.com/',
        },
      });
    });
  });

  describe('no default referer restrictions', function() {
    shared.itBehavesLikeGatekeeperAllowed('/hello', {
      headers: {
        'Referer': 'http://www.testing.com/',
      },
    });
  });

  describe('no referer restrictions with empty referer list', function() {
    shared.itBehavesLikeGatekeeperAllowed('/hello/test', {
      headers: {
        'Referer': 'http://www.testing.com/',
      },
    });
  });

  describe('user specific referer limitations', function() {
    beforeEach(function(done) {
      Factory.create('api_user', {
        settings: {
          allowed_referers: [
            '*.example.com/specific*',
            'https://google.com/specific',
            '*.yahoo.com/*',
          ],
        }
      }, function(user) {
        this.apiKey = user.api_key;
        done();
      }.bind(this));
    });

    describe('authorized if user and api settings both to evaluate true - wildcard', function() {
      shared.itBehavesLikeGatekeeperAllowed('/info/', {
        headers: {
          'Referer': 'http://www.example.com/specificstuff',
        },
      });
    });

    describe('unauthorized if user and api settings don\'t both evaluate true - wildcard', function() {
      shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
        headers: {
          'Referer': 'http://www.example.com/testing',
        },
      });
    });

    describe('unauthorized if user and api settings don\'t both evaluate true - exact', function() {
      shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
        headers: {
          'Referer': 'https://google.com/specific',
        },
      });
    });

    describe('authorized if user settings evaluate true and no api settings exist', function() {
      shared.itBehavesLikeGatekeeperAllowed('/hello', {
        headers: {
          'Referer': 'http://www.yahoo.com/',
        },
      });
    });

    describe('unauthorized if user settings evaluate false and no api settings exist', function() {
      shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
        headers: {
          'Referer': 'http://www.bing.com/',
        },
      });
    });

    describe('no referer restrictions with empty referer list', function() {
      beforeEach(function(done) {
        Factory.create('api_user', {
          settings: {
            allowed_referers: [],
          }
        }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED', {
        headers: {
          'Referer': 'http://www.foobar.com/',
        },
      });
    });
  });
});
