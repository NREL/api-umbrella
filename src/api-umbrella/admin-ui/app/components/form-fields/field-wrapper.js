// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { computed } from '@ember/object';
import { or } from '@ember/object/computed';
import { observes, on } from '@ember-decorators/object';
import Ember from 'ember';
import classic from 'ember-classic-decorator';

@classic
export default class FieldWrapper extends Component {
  // eslint-disable-next-line ember/require-tagless-components
  tagName = 'div';

  canShowErrors = false;

  @or('labelForId', 'inputId')
  labelFor;

  @on('init')
  // eslint-disable-next-line ember/no-observers
  @observes('fieldName')
  fieldNameDidChange() {
    let fieldName = this.fieldName;
    let fieldValidations = 'model.validations.attrs.' + fieldName;
    Ember.mixin(this, {
      fieldErrorMessages: computed(fieldValidations + '.messages', 'canShowErrors', function() {
        if(this.canShowErrors) {
          return this.get(fieldValidations + '.messages');
        } else {
          return [];
        }
      }),
      fieldHasErrors: computed(fieldValidations + '.isValid', 'canShowErrors', function() {
        if(this.canShowErrors) {
          return (this.get(fieldValidations + '.isValid') === false);
        } else {
          return false;
        }
      }),
    });
  }

  @computed('fieldHasErrors')
  get wrapperErrorClass() {
    if(this.fieldHasErrors) {
      return 'has-error';
    } else {
      return '';
    }
  }

  // Don't show errors until the field has been unfocused. This prevents all
  // the inline errors from showing up on initial render.
  focusOut() {
    this.set('canShowErrors', true);
  }

  // If the page is submitted, show any errors on the page (even if the fields
  // haven't been focused and then unfocused yet).
  //
  // eslint-disable-next-line ember/no-observers
  @observes('model.clientErrors')
  showErrorsOnSubmit() {
    this.set('canShowErrors', true);
  }

  // Anytime the model changes, reset the error display so errors aren't
  // displayed until the field is unfocused again.
  //
  // This helps handle modals where the same form might be reused multiple
  // times. Without this, errors would show up immediately the second time the
  // modal is opened if all the fields were unfocused the first time the modal
  // was opened.
  //
  // eslint-disable-next-line ember/no-observers
  @observes('model')
  hideErrorsOnModelChange() {
    this.set('canShowErrors', false);
  }
}
