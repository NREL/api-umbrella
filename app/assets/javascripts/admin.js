//= require jquery_ujs
//= require rails.validations
//= require vendor/jquery.slugify
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
