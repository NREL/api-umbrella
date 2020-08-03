'use strict';

const browsers = [
  '> 1%',
  'last 2 versions',
  'not ie <= 8',
];

const isCI = Boolean(process.env.CI);
const isProduction = process.env.EMBER_ENV === 'production';

if(isCI || isProduction) {
  browsers.push('ie 11');
}

module.exports = {
  browsers,
};
