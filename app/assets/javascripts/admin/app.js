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

Admin = Ember.Application.create({
  LOG_TRANSITIONS: true,

  rootElement: "#content"
});

Ember.EasyForm.Tooltip = Ember.EasyForm.BaseView.extend({
  tagName: 'a',
  attributeBindings: ['title', 'rel'],
  template: Ember.Handlebars.compile('<i class="icon-question-sign"></i>'),
  rel: 'tooltip',

  didInsertElement: function() {
    this._super();

    this.$().qtip({
      show: {
        event: "click",
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
    }).bind("click", function(event) {
      event.preventDefault();
    });
    console.info('inserted');
  },
});


Ember.Handlebars.registerHelper('tooltip-field', function(property, options) {
  options = Ember.EasyForm.processOptions(property, options);
  options.hash.viewName = 'tooltip-field-'+options.data.view.elementId;
  return Ember.Handlebars.helpers.view.call(this, Ember.EasyForm.Tooltip, options);
});


Ember.TEMPLATES['easyForm/wrapped_input'] = Ember.Handlebars.compile('<div class="control-label">{{label-field propertyBinding=view.property textBinding=view.label}}{{#if view.tooltip}}{{tooltip-field titleBinding=view.tooltip}}{{/if}}</div><div class="{{unbound view.controlsWrapperClass}}">{{partial "easyForm/inputControls"}}</div>');

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

    this.$().closest('form').submit(_.bind(function() {
      this.$().val(this.editor.getSession().getValue());
      this.$().trigger('change');
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
