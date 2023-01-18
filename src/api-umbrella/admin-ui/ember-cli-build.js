'use strict';

const EmberApp = require('ember-cli/lib/broccoli/ember-app');
const sass = require('sass');
const autoprefixer = require('autoprefixer');

module.exports = function(defaults) {
  const app = new EmberApp(defaults, {
    autoImport: {
      alias: {
        'jQuery-QueryBuilder': 'jQuery-QueryBuilder/dist/js/query-builder.standalone',
        bootbox: 'bootbox/bootbox',
        diff: 'diff/dist/diff',
        inflection: 'inflection/lib/inflection',
        numeral: 'numeral/numeral',
        selectize: 'selectize/dist/js/standalone/selectize',
      },

      webpack: {
        externals: { jquery: 'jQuery' },
      },
    },

    sourcemaps: {
      // Always enable sourcemaps, even for the production build.
      enabled: true,
    },

    sassOptions: {
      implementation: sass,

      // The Sass number precision must be increased to 8 for Bootstrap, or
      // else certain things don't line up:
      // https://github.com/twbs/bootstrap-sass#sass-number-precision
      precision: 8,
    },

    postcssOptions: {
      compile: {
        enabled: false,
        map: false,
      },
      filter: {
        enabled: true,
        plugins: [
          {
            module: autoprefixer,
          },
        ],
        exclude: ['**/*.css.map'],
      },
    },

    'ember-cli-babel': {
      includePolyfill: true,
    },

    'ember-bootstrap': {
      'bootstrapVersion': 4,
      'importBootstrapFont': false,
      'importBootstrapCSS': false,
    },

    'ember-simple-auth': {
      useSessionSetupMethod: true,
    },
  });

  // Use `app.import` to add additional libraries to the generated
  // output files.
  //
  // If you need to use different assets in different
  // environments, specify an object as the first parameter. That
  // object's keys should be the environment name and the values
  // should be the asset to use in that environment.
  //
  // If the library that you are including contains AMD or ES6
  // modules that you would like to import into your application
  // please specify an object with the list of modules as keys
  // along with the exports of each module as its value.

  return app.toTree();
};
