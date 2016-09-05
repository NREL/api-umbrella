import Ember from 'ember';

export default Ember.Component.extend({
  canShowErrors: false,

  fieldNameDidChange: Ember.on('init', Ember.observer('fieldName', function() {
    let fieldName = this.get('fieldName');
    let fieldValidations = 'model.validations.attrs.' + fieldName;
    Ember.mixin(this, {
      fieldErrorMessages: Ember.computed(fieldValidations + '.messages', 'canShowErrors', function() {
        if(this.get('canShowErrors')) {
          return this.get(fieldValidations + '.messages');
        } else {
          return [];
        }
      }),
      fieldHasErrors: Ember.computed(fieldValidations + '.isValid', 'canShowErrors', function() {
        if(this.get('canShowErrors')) {
          return (this.get(fieldValidations + '.isValid') === false);
        } else {
          return false;
        }
      }),
    });
  })),

  wrapperErrorClass: Ember.computed('fieldHasErrors', function() {
    if(this.get('fieldHasErrors')) {
      return 'has-error';
    } else {
      return '';
    }
  }),

  // Don't show errors until the field has been unfocused. This prevents all
  // the inline errors from showing up on initial render.
  focusOut() {
    this.set('canShowErrors', true);
  },

  // Anytime the model changes, reset the error display so errors aren't
  // displayed until the field is unfocused again.
  //
  // This helps handle modals where the same form might be reused multiple
  // times. Without this, errors would show up immediately the second time the
  // modal is opened if all the fields were unfocused the first time the modal
  // was opened.
  hideErrorsOnModelChange: Ember.observer('model', function() {
    this.set('canShowErrors', false);
  }),
});
