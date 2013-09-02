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
