'use strict';

var fs = require('fs'),
    objectPath = require('object-path'),
    path = require('path'),
    yaml = require('js-yaml');

var testFileConfigPath = path.resolve(__dirname, '../config/test.yml');
var data = fs.readFileSync(testFileConfigPath);
var config = yaml.safeLoad(data.toString());
module.exports = objectPath(config);
