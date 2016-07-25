/*jshint node:true*/
/* global require, module */
var EmberApp = require('ember-cli/lib/broccoli/ember-app');

module.exports = function(defaults) {
  var app = new EmberApp(defaults, {
    // Add options here
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

  app.import('bower_components/ace-builds/src-noconflict/ace.js');
  app.import('bower_components/ace-builds/src-noconflict/mode-json.js');
  app.import('bower_components/ace-builds/src-noconflict/mode-xml.js');
  app.import('bower_components/ace-builds/src-noconflict/mode-yaml.js');
  app.import('bower_components/blockUI/jquery.blockUI.js');
  app.import('bower_components/bootbox/bootbox.js');
  app.import('bower_components/bootstrap-sass/assets/javascripts/bootstrap.js');
  app.import('bower_components/bootstrap-sass/assets/fonts/bootstrap/glyphicons-halflings-regular.eot', { destDir: 'fonts/bootstrap' });
  app.import('bower_components/bootstrap-sass/assets/fonts/bootstrap/glyphicons-halflings-regular.svg', { destDir: 'fonts/bootstrap' });
  app.import('bower_components/bootstrap-sass/assets/fonts/bootstrap/glyphicons-halflings-regular.ttf', { destDir: 'fonts/bootstrap' });
  app.import('bower_components/bootstrap-sass/assets/fonts/bootstrap/glyphicons-halflings-regular.woff', { destDir: 'fonts/bootstrap' });
  app.import('bower_components/bootstrap-sass/assets/fonts/bootstrap/glyphicons-halflings-regular.woff2', { destDir: 'fonts/bootstrap' });
  app.import('bower_components/datatables/media/css/dataTables.bootstrap.css');
  app.import('bower_components/datatables/media/js/jquery.dataTables.js');
  app.import('bower_components/datatables/media/js/dataTables.bootstrap.js');
  app.import('bower_components/font-awesome/fonts/fontawesome-webfont.eot', { destDir: 'fonts' });
  app.import('bower_components/font-awesome/fonts/fontawesome-webfont.svg', { destDir: 'fonts' });
  app.import('bower_components/font-awesome/fonts/fontawesome-webfont.ttf', { destDir: 'fonts' });
  app.import('bower_components/font-awesome/fonts/fontawesome-webfont.woff', { destDir: 'fonts' });
  app.import('bower_components/font-awesome/fonts/fontawesome-webfont.woff2', { destDir: 'fonts' });
  app.import('bower_components/inflection/lib/inflection.js');
  app.import('bower_components/jQuery-QueryBuilder/dist/js/query-builder.standalone.js');
  app.import('bower_components/jQuery-QueryBuilder/dist/js/query-builder.standalone.js');
  app.import('bower_components/jquery-bbq-deparam/jquery-deparam.js');
  app.import('bower_components/jquery.scrollTo/jquery.scrollTo.js');
  app.import('bower_components/jsdiff/diff.js');
  app.import('bower_components/jstz-detect/jstz.js');
  app.import('bower_components/lodash/dist/lodash.js');
  app.import('bower_components/marked/lib/marked.js');
  app.import('bower_components/moment/moment.js');
  app.import('bower_components/pnotify/dist/pnotify.css');
  app.import('bower_components/pnotify/dist/pnotify.js');
  app.import('bower_components/qtip2/jquery.qtip.css');
  app.import('bower_components/qtip2/jquery.qtip.js');
  app.import('bower_components/selectize/dist/css/selectize.default.css');
  app.import('bower_components/selectize/dist/js/standalone/selectize.js');
  app.import('bower_components/jquery-ui/ui/version.js');
  app.import('bower_components/jquery-ui/ui/data.js');
  app.import('bower_components/jquery-ui/ui/ie.js');
  app.import('bower_components/jquery-ui/ui/scroll-parent.js');
  app.import('bower_components/jquery-ui/ui/widget.js');
  app.import('bower_components/jquery-ui/ui/widgets/mouse.js');
  app.import('bower_components/jquery-ui/ui/widgets/sortable.js');
  app.import('vendor/dirtyforms/jquery.dirtyforms.js');
  app.import('vendor/jquery.truncate.js');

  app.import('bower_components/bootstrap-daterangepicker/daterangepicker.js');

  return app.toTree();
};
