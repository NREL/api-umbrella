/*jshint node:true*/
/* global require, module */
var EmberApp = require('ember-cli/lib/broccoli/ember-app');

module.exports = function(defaults) {
  var app = new EmberApp(defaults, {
    sassOptions: {
      includePaths: [
        'bower_components/bootstrap-sass/vendor/assets/stylesheets',
      ],
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

  app.import('vendor/datatables-plugins/dataTables.bootstrap.css');

  app.import('bower_components/ember/ember-template-compiler.js');
  //app.import('bower_components/jquery/jquery.js');
  //app.import('bower_components/jquery_ujs.js');
  app.import('bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-transition.js');
  app.import('bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-affix.js');
  app.import('bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-alert.js');
  app.import('bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-button.js');
  app.import('bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-carousel.js');
  app.import('bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-collapse.js');
  app.import('bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-dropdown.js');
  app.import('bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-modal.js');
  app.import('bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-scrollspy.js');
  app.import('bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-tab.js');
  app.import('bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-tooltip.js');
  app.import('bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-popover.js');
  app.import('bower_components/bootstrap-sass/vendor/assets/javascripts/bootstrap-typeahead.js');
  app.import('bower_components/ace-builds/src/ace.js');
  app.import('bower_components/ace-builds/src/mode-json.js');
  app.import('bower_components/ace-builds/src/mode-xml.js');
  app.import('bower_components/ace-builds/src/mode-yaml.js');
  //app.import('bower_components/handlebars.js');
  //app.import('bower_components/ember.js');
  app.import('bower_components/qtip2/jquery.qtip.js');
  app.import('bower_components/lodash/dist/lodash.compat.js');
  app.import('bower_components/datatables/media/js/jquery.dataTables.js');
  app.import('vendor/datatables-plugins/dataTables.bootstrap.js');
  app.import('bower_components/jsdiff/diff.js');
  app.import('bower_components/ic-ajax/dist/globals/main.js');
  app.import('vendor/ember-model/ember-model.js');
  app.import('vendor/ember-easyForm.js');
  app.import('vendor/ember-validations.js');
  app.import('bower_components/marked/lib/marked.js');
  app.import('bower_components/pnotify/pnotify.core.js');
  app.import('bower_components/bootbox/bootbox.js');
  app.import('bower_components/jquery.scrollTo/jquery.scrollTo.js');
  app.import('vendor/jquery-ui-1.10.3.custom.js');
  app.import('bower_components/jquery-bbq-deparam/jquery-deparam.js');
  app.import('bower_components/selectize/dist/js/standalone/selectize.js');
  app.import('bower_components/inflection/lib/inflection.js');
  app.import('bower_components/jstz-detect/jstz.js');
  app.import('vendor/jquery.slugify.js');
  app.import('bower_components/moment/moment.js');
  app.import('bower_components/bootstrap-daterangepicker/daterangepicker.js');
  app.import('bower_components/numeral/numeral.js');
  app.import('vendor/jquery.blockUI.js');
  app.import('vendor/jQuery-QueryBuilder/query-builder.standalone.js');
  app.import('bower_components/spinjs/spin.js');
  app.import('vendor/dirtyforms/jquery.dirtyforms.js');
  app.import('vendor/jquery.truncate.js');

  return app.toTree();
};
