import Mixin from '@ember/object/mixin'
import { inject } from '@ember/service';
import { success } from '@pnotify/core';
import LoadingButton from 'api-umbrella-admin-ui/utils/loading-button';
import bootbox from 'bootbox';
import scrollTo from 'jquery.scrollto';
import isFunction from 'lodash-es/isFunction';

// eslint-disable-next-line ember/no-new-mixins
export default Mixin.create({
  router: inject(),

  scrollToErrors(button) {
    LoadingButton.reset(button);
    scrollTo('#error_messages', { offset: -60, duration: 200 });
  },

  afterSaveComplete(options, button) {
    LoadingButton.reset(button);
    success({
      title: 'Saved',
      text: (isFunction(options.message)) ? options.message(this.model) : options.message,
      textTrusted: true,
    });

    this.router.transitionTo(options.transitionToRoute);
  },

  saveRecord(options) {
    const button = options.element.querySelector('.save-button');
    LoadingButton.loading(button);

    this.setProperties({
      'model.clientErrors': [],
      'model.serverErrors': [],
    });

    this.model.validate().then(function() {
      if(this.model.validations.isValid === false) {
        this.set('model.clientErrors', this.model.validations.errors);
        this.scrollToErrors(button);
      } else {
        this.model.save().then(function() {
          if(options.afterSave) {
            options.afterSave(this.afterSaveComplete.bind(this, options, button));
          } else {
            this.afterSaveComplete(options, button);
          }
        }.bind(this), function(error) {
          // Set the errors from the server response on a "serverErrors" property
          // for the error-messages component display.
          if(error && error.errors) {
            this.set('model.serverErrors', error.errors);
          } else {
            // eslint-disable-next-line no-console
            console.error('Unexpected save error: ', error);
            this.set('model.serverErrors', [{ message: 'Unexpected error' }]);
          }

          this.scrollToErrors(button);
        }.bind(this));
      }
    }.bind(this));
  },

  destroyRecord(options) {
    bootbox.confirm(options.prompt, function(result) {
      if(result) {
        this.model.destroyRecord().then(function() {
          success({
            title: 'Deleted',
            text: (isFunction(options.message)) ? options.message(this.model) : options.message,
            textTrusted: true,
          });

          this.router.transitionTo(options.transitionToRoute);
        }.bind(this), function(response) {
          bootbox.alert('Unexpected error deleting record: ' + response.responseText);
        });
      }
    }.bind(this));
  },
});
