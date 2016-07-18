import Ember from 'ember';

export default Ember.Component.extend({
  canShoErrors: false,

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

  focusOut() {
    this.set('canShowErrors', true);
  },
});
