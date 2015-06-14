'use strict';

require('../test_helper');

var Factory = require('factory-lady');

describe('ApiUmbrellaGatekeper', function() {
  shared.runServer({
    apis: [
      {
        frontend_host: 'localhost',
        backend_host: 'example.com',
        url_matches: [
          {
            frontend_prefix: '/info/no-key/',
            backend_prefix: '/info/no-key/',
          }
        ],
        settings: {
          disable_api_key: true,
          required_roles: ['restricted'],
        },
      },
      {
        frontend_host: 'localhost',
        backend_host: 'example.com',
        url_matches: [
          {
            frontend_prefix: '/info/no-parent-roles/',
            backend_prefix: '/info/no-parent-roles/',
          }
        ],
        sub_settings: [
          {
            http_method: 'any',
            regex: '^/info/no-parent-roles/sub/',
            settings: {
              required_roles: ['sub'],
            },
          },
        ],
      },
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
          required_roles: ['restricted', 'private'],
        },
        sub_settings: [
          {
            http_method: 'any',
            regex: '^/info/sub/',
            settings: {
              required_roles: ['sub'],
            },
          },
          {
            http_method: 'any',
            regex: '^/info/sub-null-roles/',
            settings: {
              required_roles: null,
            },
          },
          {
            http_method: 'any',
            regex: '^/info/sub-empty-roles/',
            settings: {
              required_roles: [],
            },
          },
          {
            http_method: 'any',
            regex: '^/info/sub-unset-roles/',
            settings: {
            },
          },
          {
            http_method: 'any',
            regex: '^/info/sub-override-true/',
            settings: {
              required_roles: ['sub'],
              required_roles_override: true,
            },
          },
          {
            http_method: 'any',
            regex: '^/info/sub-override-false/',
            settings: {
              required_roles: ['sub'],
              required_roles_override: false,
            },
          },
          {
            http_method: 'any',
            regex: '^/info/sub-null-roles-override/',
            settings: {
              required_roles: null,
              required_roles_override: true,
            },
          },
          {
            http_method: 'any',
            regex: '^/info/sub-empty-roles-override/',
            settings: {
              required_roles: [],
              required_roles_override: true,
            },
          },
          {
            http_method: 'any',
            regex: '^/info/sub-unset-roles-override/',
            settings: {
              required_roles_override: true,
            },
          },
          {
            http_method: 'any',
            regex: '^/info/sub-no-key-required/',
            settings: {
              disable_api_key: true,
            },
          },
        ],
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

  describe('role validation', function() {
    describe('unauthorized api_key with null roles', function() {
      beforeEach(function setupApiUser(done) {
        Factory.create('api_user', { roles: null }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED');
    });

    describe('unauthorized api_key with empty roles', function() {
      beforeEach(function setupApiUser(done) {
        Factory.create('api_user', { roles: [] }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED');
    });

    describe('unauthorized api_key with other roles', function() {
      beforeEach(function setupApiUser(done) {
        Factory.create('api_user', { roles: ['something', 'else'] }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED');
    });

    describe('unauthorized api_key with only one of the required roles', function() {
      beforeEach(function setupApiUser(done) {
        Factory.create('api_user', { roles: ['private'] }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED');
    });

    describe('authorized api_key with all of the required role', function() {
      beforeEach(function setupApiUser(done) {
        Factory.create('api_user', { roles: ['restricted', 'private'] }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperAllowed('/info/');
    });

    describe('api_key with admin roles is not authorized automatically', function() {
      beforeEach(function setupApiUser(done) {
        Factory.create('api_user', { roles: ['admin'] }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_UNAUTHORIZED');
    });

    describe('sub-url with additional role requirements', function() {
      describe('unauthorized api_key with only the parent roles', function() {
        beforeEach(function setupApiUser(done) {
          Factory.create('api_user', { roles: ['private', 'restricted'] }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperBlocked('/info/sub/', 403, 'API_KEY_UNAUTHORIZED');
      });

      describe('unauthorized api_key with only the sub role', function() {
        beforeEach(function setupApiUser(done) {
          Factory.create('api_user', { roles: ['sub'] }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperBlocked('/info/sub/', 403, 'API_KEY_UNAUTHORIZED');
      });

      describe('authorized api_key with all the parent and sub roles', function() {
        beforeEach(function setupApiUser(done) {
          Factory.create('api_user', { roles: ['sub', 'private', 'restricted'] }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/sub/');
      });
    });

    describe('sub-url with null role requirements', function() {
      describe('unauthorized api_key with no roles', function() {
        shared.itBehavesLikeGatekeeperBlocked('/info/sub-null-roles/', 403, 'API_KEY_UNAUTHORIZED');
      });

      describe('authorized api_key with all the parent roles', function() {
        beforeEach(function setupApiUser(done) {
          Factory.create('api_user', { roles: ['private', 'restricted'] }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/sub-null-roles/');
      });
    });

    describe('sub-url with empty role requirements', function() {
      describe('unauthorized api_key with no roles', function() {
        shared.itBehavesLikeGatekeeperBlocked('/info/sub-empty-roles/', 403, 'API_KEY_UNAUTHORIZED');
      });

      describe('authorized api_key with all the parent roles', function() {
        beforeEach(function setupApiUser(done) {
          Factory.create('api_user', { roles: ['private', 'restricted'] }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/sub-empty-roles/');
      });
    });

    describe('sub-url with unset role requirements', function() {
      describe('unauthorized api_key with no roles', function() {
        shared.itBehavesLikeGatekeeperBlocked('/info/sub-unset-roles/', 403, 'API_KEY_UNAUTHORIZED');
      });

      describe('authorized api_key with all the parent roles', function() {
        beforeEach(function setupApiUser(done) {
          Factory.create('api_user', { roles: ['private', 'restricted'] }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/sub-unset-roles/');
      });
    });

    describe('sub-url with overriding role requirements', function() {
      describe('unauthorized api_key with no roles', function() {
        shared.itBehavesLikeGatekeeperBlocked('/info/sub-override-true/', 403, 'API_KEY_UNAUTHORIZED');
      });

      describe('authorized api_key with only the sub role', function() {
        beforeEach(function setupApiUser(done) {
          Factory.create('api_user', { roles: ['sub'] }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/sub-override-true/');
      });
    });

    describe('sub-url with overriding explicitly false role requirements', function() {
      describe('unauthorized api_key with only the parent roles', function() {
        beforeEach(function setupApiUser(done) {
          Factory.create('api_user', { roles: ['private', 'restricted'] }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperBlocked('/info/sub-override-false/', 403, 'API_KEY_UNAUTHORIZED');
      });

      describe('unauthorized api_key with only the sub role', function() {
        beforeEach(function setupApiUser(done) {
          Factory.create('api_user', { roles: ['sub'] }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperBlocked('/info/sub-override-false/', 403, 'API_KEY_UNAUTHORIZED');
      });

      describe('authorized api_key with all the parent and sub roles', function() {
        beforeEach(function setupApiUser(done) {
          Factory.create('api_user', { roles: ['sub', 'private', 'restricted'] }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/sub-override-false/');
      });
    });

    describe('sub-url with overriding null role requirements', function() {
      describe('authorized api_key with no roles', function() {
        shared.itBehavesLikeGatekeeperAllowed('/info/sub-null-roles-override/');
      });
    });

    describe('sub-url with overriding empty role requirements', function() {
      describe('authorized api_key with no roles', function() {
        shared.itBehavesLikeGatekeeperAllowed('/info/sub-empty-roles-override/');
      });
    });

    describe('sub-url with overriding unset role requirements', function() {
      describe('authorized api_key with no roles', function() {
        shared.itBehavesLikeGatekeeperAllowed('/info/sub-unset-roles-override/');
      });
    });

    describe('sub-url with role requirements but a parent with no requirements', function() {
      describe('unauthorized api_key with only the sub role', function() {
        shared.itBehavesLikeGatekeeperBlocked('/info/no-parent-roles/sub/', 403, 'API_KEY_UNAUTHORIZED');
      });

      describe('authorized api_key with all the parent and sub roles', function() {
        beforeEach(function setupApiUser(done) {
          Factory.create('api_user', { roles: ['sub'] }, function(user) {
            this.apiKey = user.api_key;
            done();
          }.bind(this));
        });

        shared.itBehavesLikeGatekeeperAllowed('/info/no-parent-roles/sub/');
      });
    });

    describe('non-matching path', function() {
      beforeEach(function setupApiUser(done) {
        Factory.create('api_user', { roles: null }, function(user) {
          this.apiKey = user.api_key;
          done();
        }.bind(this));
      });

      shared.itBehavesLikeGatekeeperAllowed('/not/restricted');
    });

    describe('no api key for an api that requires keys and roles', function() {
      beforeEach(function setupApiUser() {
        this.apiKey = '';
      });

      shared.itBehavesLikeGatekeeperBlocked('/info/', 403, 'API_KEY_MISSING');
    });

    describe('api requires roles but no api key actually required', function() {
      describe('no api key given', function() {
        beforeEach(function setupApiUser() {
          this.apiKey = '';
        });

        shared.itBehavesLikeGatekeeperBlocked('/info/no-key/', 403, 'API_KEY_UNAUTHORIZED');
      });

      describe('api key without roles given', function() {
        shared.itBehavesLikeGatekeeperBlocked('/info/no-key/', 403, 'API_KEY_UNAUTHORIZED');
      });
    });

    describe('parent api requires roles but sub settings disable api key requirements', function() {
      describe('no api key given', function() {
        beforeEach(function setupApiUser() {
          this.apiKey = '';
        });

        shared.itBehavesLikeGatekeeperBlocked('/info/sub-no-key-required/', 403, 'API_KEY_UNAUTHORIZED');
      });

      describe('api key without roles given', function() {
        shared.itBehavesLikeGatekeeperBlocked('/info/sub-no-key-required/', 403, 'API_KEY_UNAUTHORIZED');
      });
    });
  });
});
