import Ember from 'ember';

export default Ember.Component.extend({
  fieldNameDidChange: Ember.on('init', Ember.observer('fieldName', function() {
    let fieldName = this.get('fieldName');
    let fieldValidations = 'model.validations.attrs.' + fieldName;
    Ember.mixin(this, {
      fieldErrorMessages: Ember.computed.reads(fieldValidations + '.messages'),
      fieldHasErrors: Ember.computed(fieldValidations + '.isValid', function() {
        return (this.get(fieldValidations + '.isValid') === false);
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
});
