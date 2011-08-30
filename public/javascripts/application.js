$(document).ready(function() {
  $("textarea.editor").ckeditor({
    extraPlugins: "syntaxhighlight",
    height: 500,
    contentsCss: [
      "/stylesheets/yui/reset.css",
      "/stylesheets/yui/base.css",
      "/stylesheets/yui/fonts.css",
      "/stylesheets/doc_service.css",
      "/stylesheets/editor.css",
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
      ["Code", "Table", "Image"],
      ["Source"]
    ]
  });
});
