//= require jquery_ujs
//= require bootstrap
//= require rails.validations
//= require handlebars
//= require ember
//= require vendor/qtip/jquery.qtip
//= require vendor/lodash.compat
//= require vendor/DataTables/media/js/jquery.dataTables
//= require vendor/DataTables-Plugins/integration/bootstrap/2/dataTables.bootstrap
//= require vendor/ember-model
//= require vendor/ember-easyForm
//= require vendor/pnotify/jquery.pnotify
//= require vendor/bootbox/bootbox
//= require vendor/jquery-ui-1.10.3.custom
//= require vendor/deparam/jquery-deparam
//= require vendor/selectize.js/dist/js/standalone/selectize.js
//= require vendor/inflections/underscore.inflections
//= require vendor/jstz
//= require vendor/jquery.slugify
//= require vendor/daterangepicker/moment
//= require vendor/daterangepicker/daterangepicker
//= require vendor/Numeral-js/numeral
//= require vendor/spin.js/dist/spin
//= require vendor/dirtyforms/jquery.dirtyforms
//= require vendor/dirtyforms/helpers/ckeditor
//= require admin/app
//= require_self

$(document).ready(function() {
  CKEDITOR.replace("api_doc_service_body", {
    extraPlugins: "pbckcode",
    height: 500,
    contentsCss: [
      "/assets/application.css",
      "/assets/ckeditor.css",
    ],
    stylesSet: [
      {
        name: "Section",
        element: "h2",
      },
      {
        name: "Sub-Section",
        element: "h3",
      },
      {
        name: "Service URL",
        element: "div",
        attributes: { "class" : "docs-service-url" }
      },
      {
        name: "Example URL",
        element: "div",
        attributes: { "class" : "docs-example-url" }
      }
    ],
    toolbar: [
      ["Styles"],
      ["Bold", "Italic", "-", "RemoveFormat"],
      ["Link", "Unlink"],
      ["NumberedList", "BulletedList", "-", "Outdent", "Indent"],
      ["pbckcode", "Table", "Image"],
      ["Source"]
    ],
    pbckcode: {
      modes: [
        ["JSON", "json"],
        ["XML", "xml"],
        ["Text", "text"]
      ],
      defaultMode: "json"
    }
  });

  // Use the default browser "beforeunload" dialog.
  $.DirtyForms.dialog = false 
  $(window).bind('beforeunload', function(e) {
    if($.DirtyForms.isDirty()) {
      return $.DirtyForms.message;
    } else {
      return;
    }
  });

  $("form").dirtyForms();

  // Setup qTip defaults.
  $("a[rel=tooltip]").qtip({
    show: {
      event: "click",
      solo: true
    },
    hide: {
      event: "unfocus"
    },
    position: {
      viewport: true,
      my: "bottom left",
      at: "top center",
      adjust: {
        y: 2
      }
    }
  }).bind("click", function(event) {
    event.preventDefault();
  });
});
