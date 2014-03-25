//= require jquery_ujs
//= require bootstrap
//= require rails.validations
//= require handlebars
//= require ember
//= require qtip2
//= require lodash/lodash.compat
//= require vendor/DataTables/media/js/jquery.dataTables
//= require vendor/DataTables-Plugins/integration/bootstrap/2/dataTables.bootstrap
//= require ember-model
//= require vendor/ember-easyForm
//= require pnotify
//= require bootbox
//= require vendor/jquery-ui-1.10.3.custom
//= require jquery-bbq-deparam
//= require selectize/standalone/selectize
//= require inflection
//= require jstz-detect/jstz
//= require vendor/jquery.slugify
//= require moment
//= require bootstrap-daterangepicker
//= require livestampjs/livestamp
//= require numeral
//= require vendor/jquery.blockUI
//= require spinjs
//= require vendor/dirtyforms/jquery.dirtyforms
//= require vendor/dirtyforms/helpers/ckeditor
//= require admin/app
//= require_self

$(document).ready(function() {
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
  $(document).on('click', 'a[rel=tooltip]', function(event) {
    $(this).qtip({
      overwrite: false,
      show: {
        event: event.type,
        ready: true,
        solo: true
      },
      hide: {
        event: "unfocus"
      },
      style: {
        classes: 'qtip-bootstrap',
      },
      position: {
        viewport: true,
        my: "bottom left",
        at: "top center",
        adjust: {
          y: 2
        }
      }
    }, event);

    event.preventDefault();
  });

  $(document).on('click', 'a[rel=popover]', function(event) {
    $(this).qtip({
      overwrite: false,
      show: {
        event: event.type,
        ready: true,
        solo: true
      },
      hide: {
        event: "unfocus"
      },
      content: {
        text: function(event, api) {
          var target = $(event.target).attr("href");
          var content = $(target).html();

          return content;
        },
      },
      style: {
        classes: 'qtip-bootstrap qtip-wide',
      },
      position: {
        viewport: false,
        my: "top left",
        at: "bottom center",
        adjust: {
          y: 2
        }
      }
    }, event);

    event.preventDefault();
  });
});
