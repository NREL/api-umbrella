import { computed, observer } from '@ember/object';

import Component from '@ember/component';
import Ember from 'ember';
import { on } from '@ember/object/evented';

export default Component.extend({
  canShowErrors: false,

  labelFor: computed('labelForId', 'inputId', function() {
    return this.get('labelForId') || this.get('inputId');
  }),

  // eslint-disable-next-line ember/no-on-calls-in-components
  fieldNameDidChange: on('init', observer('fieldName', function() {
    let fieldName = this.get('fieldName');
    let fieldValidations = 'model.validations.attrs.' + fieldName;
    Ember.mixin(this, {
      fieldErrorMessages: computed(fieldValidations + '.messages', 'canShowErrors', function() {
        if(this.get('canShowErrors')) {
          return this.get(fieldValidations + '.messages');
        } else {
          return [];
        }
      }),
      fieldHasErrors: computed(fieldValidations + '.isValid', 'canShowErrors', function() {
        if(this.get('canShowErrors')) {
          return (this.get(fieldValidations + '.isValid') === false);
        } else {
          return false;
        }
      }),
    });
  })),

  wrapperErrorClass: computed('fieldHasErrors', function() {
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

  // If the page is submitted, show any errors on the page (even if the fields
  // haven't been focused and then unfocused yet).
  showErrorsOnSubmit: observer('model.clientErrors', function() {
    this.set('canShowErrors', true);
  }),

  // Anytime the model changes, reset the error display so errors aren't
  // displayed until the field is unfocused again.
  //
  // This helps handle modals where the same form might be reused multiple
  // times. Without this, errors would show up immediately the second time the
  // modal is opened if all the fields were unfocused the first time the modal
  // was opened.
  hideErrorsOnModelChange: observer('model', function() {
    this.set('canShowErrors', false);
  }),
});
