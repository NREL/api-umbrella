//= require_self
//= require_tree ./models
//= require ./controllers/apis/nested_form_controller
//= require ./controllers/apis/sortable_controller
//= require_tree ./controllers
//= require_tree ./views
//= require_tree ./helpers
//= require_tree ./templates
//= require ./router
//= require_tree ./routes

//Ember.LOG_BINDINGS = true

// Set Bootbox defaults.
bootbox.animate(false);

// Pines Notify Defaults.
$.pnotify.defaults.history = false;
$.pnotify.defaults.width = '400px';
$.pnotify.defaults.sticker = false;
$.pnotify.defaults.animate_speed = 'fast';
$.pnotify.defaults.icon = false;

(function() {
  var versionParts = Ember.VERSION.split('.');
  var major = parseInt(versionParts[0]);
  var minor = parseInt(versionParts[1]);
  var patch = parseInt(versionParts[2]);
  if(major > 1 || (major == 1 && (minor > 1 || patch > 2))) {
    Ember.Logger.warn('WARNING: New Ember version detected. URL hash monkey patch possibly no longer needed or broken. Check for compatibility.');
  }

  var get = Ember.get, set = Ember.set;

  // Fix URL hash parsing across browsers. Because we're putting query
  // parameters in the URL, we expect special characters which escape
  // differently across browsers with location.hash. So this is a monkey patch
  // to use location.href instead.
  // https://github.com/emberjs/ember.js/issues/3000
  // https://github.com/emberjs/ember.js/issues/3263
  //
  // All of this should be revisited once query-params lands, since this will
  // probably clean this up: https://github.com/emberjs/ember.js/pull/3182
  Ember.HashLocation.reopen({
    getURL: function() {
      var href = get(this, 'location').href;

      var hashIndex = href.indexOf('#');
      if (hashIndex === -1) {
        return '';
      } else {
        return href.substr(hashIndex + 1);
      }
    },

    onUpdateURL: function(callback) {
      var self = this;
      var guid = Ember.guidFor(this);

      Ember.$(window).on('hashchange.ember-location-'+guid, function() {
        Ember.run(function() {
          var path = self.getURL();
          if (get(self, 'lastSetURL') === path) { return; }

          set(self, 'lastSetURL', null);

          callback(path);
        });
      });
    },
  });
})();

Admin = Ember.Application.create({
  LOG_TRANSITIONS: true,
  LOG_TRANSITIONS_INTERNAL: true,

  rootElement: "#content"
});

Ember.EasyForm.Tooltip = Ember.EasyForm.BaseView.extend({
  tagName: 'a',
  attributeBindings: ['title', 'rel'],
  template: Ember.Handlebars.compile('<i class="icon-question-sign"></i>'),
  rel: 'tooltip',
});

Ember.Handlebars.registerBoundHelper('formatDate', function(date, format) {
  if(!format || !_.isString(format)) {
    format = 'YYYY-MM-DD HH:mm Z';
  }

  if(date) {
    return moment(date).format(format);
  } else {
    return '';
  }
});

Ember.Handlebars.helper('formatNumber', function(number) {
  return numeral(number).format('0,0');
});

Ember.Handlebars.helper('pluralize', function(word, number) {
  return (number == 1) ? word : inflection.pluralize(word);
});

Ember.Handlebars.registerHelper('tooltip-field', function(property, options) {
  options = Ember.EasyForm.processOptions(property, options);
  options.hash.viewName = 'tooltip-field-'+options.data.view.elementId;
  return Ember.Handlebars.helpers.view.call(this, Ember.EasyForm.Tooltip, options);
});

// Use a custom template for Easy Form. This adds a tooltip and wraps that in
// the control-label div with the label.
Ember.TEMPLATES['easyForm/wrapped_input'] = Ember.Handlebars.compile('<div class="control-label">{{label-field propertyBinding="view.property" textBinding="view.label"}}{{#if view.tooltip}}{{tooltip-field titleBinding="view.tooltip"}}{{/if}}</div><div class="{{unbound view.controlsWrapperClass}}">{{partial "easyForm/inputControls"}}</div>');

Ember.EasyForm.Config.registerInputType('ace', Ember.EasyForm.TextArea.extend({
  attributeBindings: ['data-ace-mode'],

  didInsertElement: function() {
    this._super();

    var aceId = this.elementId + '_ace';
    this.$().hide();
    this.$().before('<div id="' + aceId + '" class="span12"></div>');

    this.editor = ace.edit(aceId);
    this.editor.setTheme('ace/theme/textmate');
    this.editor.setShowPrintMargin(false);
    this.editor.setHighlightActiveLine(false);
    this.editor.getSession().setUseWorker(false);
    this.editor.getSession().setMode('ace/mode/' + this.$().data('ace-mode'));
    this.editor.getSession().setValue(this.$().val());

    var element = this.$();
    this.$().closest('form').submit(_.bind(function() {
      element.val(this.editor.getSession().getValue());
      element.trigger('change');
    }, this));
  },
}));

Ember.EasyForm.Config.registerWrapper('default', {
  formClass: '',
  fieldErrorClass: 'error',
  errorClass: 'help-inline',
  hintClass: 'help-block',
  inputClass: 'control-group',
  wrapControls: true,
  controlsWrapperClass: 'controls'
});

Admin.APIUmbrellaRESTAdapter = Ember.RESTAdapter.extend({
  ajaxSettings: function(url, method) {
    return {
      url: url,
      type: method,
      dataType: 'json',
      headers: {
        'X-Api-Key': webAdminAjaxApiKey
      }
    };
  }
});

// DataTables plugin to programmatically show the processing indidicator.
// https://datatables.net/plug-ins/api#fnProcessingIndicator
jQuery.fn.dataTableExt.oApi.fnProcessingIndicator = function ( oSettings, onoff )
{
  if( typeof(onoff) == 'undefined' )
  {
    onoff=true;
  }
  this.oApi._fnProcessingDisplay( oSettings, onoff );
};


// Defaults for DataTables.
_.merge($.fn.dataTable.defaults, {
  // Don't show the DataTables processing message. We'll handle the processing
  // message logic in fnInitComplete with blockui.
  "bProcessing": false,

  // Enable global searching.
  "bFilter": true,

  // Disable per-column searching.
  "bSearchable": false,

  // Re-arrange how the table and surrounding fields (pagination, search, etc)
  // are laid out.
  "sDom": 'rft<"row-fluid"<"span3 table-info"i><"span6 table-pagination"p><"span3 table-length"l>>',

  "oLanguage": {
    // Don't have an explicit label for the search field. Used the placeholder
    // created in fnInitComplete instead.
    "sSearch": "",
  },

  "fnPreDrawCallback": function() {
    if(!this.customProcessingCallbackSet) {
      // Use blockui to provide a more obvious processing message the overlays
      // the entire table (this helps for long tables, where a simple processing
      // message might appear out of your current view).
      //
      // Set this early on during pre-draw so that the processing message shows
      // up for the first load.
      this.on('processing', _.bind(function(event, settings, processing) {
        if(processing) {
          this.block({
            message: '<i class="icon-spinner icon-spin icon-large"></i>',
          });
        } else {
          this.unblock();
        }
      }, this));

      this.customProcessingCallbackSet = true;
    }
  },

  "fnInitComplete": function() {
    // Add a placeholder instead of the "Search:" label to the filter
    // input.
    $('.dataTables_filter input').attr("placeholder", "Search...");
  },
});
