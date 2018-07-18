'use strict';

let EmberApp = require('ember-cli/lib/broccoli/ember-app');

module.exports = function(defaults) {
  let app = new EmberApp(defaults, {
    sourcemaps: {
      // Always enable sourcemaps, even for the production build.
      enabled: true,
    },

    sassOptions: {
      // The Sass number precision must be increased to 8 for Bootstrap, or
      // else certain things don't line up:
      // https://github.com/twbs/bootstrap-sass#sass-number-precision
      precision: 8,
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

  // Prepend Ace before Ember, or else the "define" method from Ember's
  // loader.js conflicts with Ace after these changes in Ace v1.2.4:
  // https://github.com/ajaxorg/ace/pull/2914
  app.import('node_modules/ace-builds/src-noconflict/mode-json.js', { prepend: true });
  app.import('node_modules/ace-builds/src-noconflict/mode-xml.js', { prepend: true });
  app.import('node_modules/ace-builds/src-noconflict/mode-yaml.js', { prepend: true });
  app.import('node_modules/ace-builds/src-noconflict/ace.js', { prepend: true });

  app.import('node_modules/bootbox/bootbox.js');
  app.import('node_modules/bootstrap-sass/assets/javascripts/bootstrap.js');
  app.import('node_modules/bootstrap-sass/assets/fonts/bootstrap/glyphicons-halflings-regular.eot', { destDir: 'fonts/bootstrap' });
  app.import('node_modules/bootstrap-sass/assets/fonts/bootstrap/glyphicons-halflings-regular.svg', { destDir: 'fonts/bootstrap' });
  app.import('node_modules/bootstrap-sass/assets/fonts/bootstrap/glyphicons-halflings-regular.ttf', { destDir: 'fonts/bootstrap' });
  app.import('node_modules/bootstrap-sass/assets/fonts/bootstrap/glyphicons-halflings-regular.woff', { destDir: 'fonts/bootstrap' });
  app.import('node_modules/bootstrap-sass/assets/fonts/bootstrap/glyphicons-halflings-regular.woff2', { destDir: 'fonts/bootstrap' });
  app.import('node_modules/datatables.net-bs/css/dataTables.bootstrap.css');
  app.import('node_modules/datatables.net/js/jquery.dataTables.js');
  app.import('node_modules/datatables.net-bs/js/dataTables.bootstrap.js');
  app.import('node_modules/font-awesome/fonts/fontawesome-webfont.eot', { destDir: 'fonts' });
  app.import('node_modules/font-awesome/fonts/fontawesome-webfont.svg', { destDir: 'fonts' });
  app.import('node_modules/font-awesome/fonts/fontawesome-webfont.ttf', { destDir: 'fonts' });
  app.import('node_modules/font-awesome/fonts/fontawesome-webfont.woff', { destDir: 'fonts' });
  app.import('node_modules/font-awesome/fonts/fontawesome-webfont.woff2', { destDir: 'fonts' });
  app.import('node_modules/inflection/lib/inflection.js');
  app.import('node_modules/jQuery-QueryBuilder/dist/js/query-builder.standalone.js');
  app.import('node_modules/jQuery-QueryBuilder/dist/js/query-builder.standalone.js');
  app.import('node_modules/jquery.scrollto/jquery.scrollTo.js');
  app.import('node_modules/diff/dist/diff.js');
  app.import('node_modules/lodash/lodash.js');
  app.import('node_modules/marked/lib/marked.js');
  app.import('node_modules/qtip2/dist/jquery.qtip.css');
  app.import('node_modules/qtip2/dist/jquery.qtip.js');
  app.import('node_modules/selectize/dist/css/selectize.default.css');
  app.import('node_modules/selectize/dist/js/standalone/selectize.js');
  app.import('node_modules/jquery-ui/ui/version.js');
  app.import('node_modules/jquery-ui/ui/data.js');
  app.import('node_modules/jquery-ui/ui/ie.js');
  app.import('node_modules/jquery-ui/ui/scroll-parent.js');
  app.import('node_modules/jquery-ui/ui/widget.js');
  app.import('node_modules/jquery-ui/ui/widgets/mouse.js');
  app.import('node_modules/jquery-ui/ui/widgets/sortable.js');
  // app.import('node_modules/tbasse-jquery-truncate/jquery.truncate.js');

  return app.toTree();
};
