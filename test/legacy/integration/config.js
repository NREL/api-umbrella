'use strict';

require('../test_helper');

var fs = require('fs'),
    path = require('path'),
    yaml = require('js-yaml');

describe('config', function() {
  describe('overriding null values', function() {
    shared.runServer({
      web: {
        admin: {
          auth_strategies: {
            ldap: {
              options: {
                host: 'example.com',
              }
            },
          },
        },
      },
    });

    it('overrides a default null value', function() {
      var defaultConfig = yaml.safeLoad(fs.readFileSync(path.join(global.API_UMBRELLA_SRC_ROOT, 'config/default.yml')).toString());
      var runtimeConfig = yaml.safeLoad(fs.readFileSync('/tmp/api-umbrella-test/var/run/runtime_config.yml').toString());

      should.not.exist(defaultConfig.web.admin.auth_strategies.ldap.options);
      runtimeConfig.web.admin.auth_strategies.ldap.options.should.eql({
        host: 'example.com',
      });
    });
  });
});
