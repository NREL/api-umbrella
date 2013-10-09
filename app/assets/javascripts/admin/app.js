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
  labelClass: 'control-label',
  inputClass: 'control-group',
  wrapControls: true,
  controlsWrapperClass: 'controls'
});
