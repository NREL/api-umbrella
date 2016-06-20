'use strict';

var fs = require('fs'),
    objectPath = require('object-path'),
    path = require('path'),
    yaml = require('js-yaml');

module.exports = {
  get: function(key) {
    // Read from the config file the api-umbrella process creates after reading
    // and merging config files.
    var testFileConfigPath = '/tmp/api-umbrella-test/var/run/runtime_config.yml';

    // If we're trying to read config data before the api-umbrella processes
    // have started, then as a fallback read from the single test file. This
    // assumes these config values read early on are only in this file. So it
    // isn't quite ideal or perfect, but seems to do the trick for now (but
    // should perhaps be revisited).
    if(!fs.existsSync(testFileConfigPath)) {
      testFileConfigPath = path.resolve(__dirname, '../config/test.yml');
    }

    var data = fs.readFileSync(testFileConfigPath);
    var config = objectPath(yaml.safeLoad(data.toString()));
    return config.get(key);
  },
};
