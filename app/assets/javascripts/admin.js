//= require jquery_ujs
//= require bootstrap
//= require rails.validations
//= require handlebars
//= require vendor/underscore
//= require vendor/backbone
//= require backbone.marionette
//= require ember
//= require vendor/ember-model
//= require vendor/ember-easyForm
//= require admin/app
//= require vendor/deparam/jquery-deparam
//= require vendor/selectize.js/dist/js/standalone/selectize.js
//= require vendor/inflections/underscore.inflections
//= require vendor/jstz
//= require vendor/jquery-deserialize/src/jquery.deserialize
//= require vendor/jquery.slugify
//= require vendor/daterangepicker/moment
//= require vendor/daterangepicker/daterangepicker
//= require vendor/backbone-pageable/lib/backbone-pageable
//= require vendor/backgrid/lib/backgrid
//= require vendor/backgrid/lib/extensions/paginator/backgrid-paginator
//= require vendor/backgrid/lib/extensions/moment-cell/backgrid-moment-cell
//= require admin/backgrid_link_cell
//= require vendor/Numeral-js/numeral
//= require vendor/spin.js/dist/spin
//= require vendor/dirtyforms/jquery.dirtyforms
//= require vendor/dirtyforms/helpers/ckeditor
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
});
