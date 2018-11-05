import $ from 'jquery';
import Mixin from '@ember/object/mixin'
import PNotify from 'pnotify';
import bootbox from 'bootbox';
import { inject } from '@ember/service';
import isFunction from 'lodash-es/isFunction';
import scrollTo from 'jquery.scrollto';

export default Mixin.create({
  router: inject(),

  scrollToErrors() {
    $('#save_button').button('reset');
    scrollTo('#error_messages', { offset: -60, duration: 200 });
  },

  afterSaveComplete(options, button) {
    button.button('reset');
    PNotify.success({
      title: 'Saved',
      text: (isFunction(options.message)) ? options.message(this.model) : options.message,
      textTrusted: true,
    });

    this.router.transitionTo(options.transitionToRoute);
  },

  saveRecord(options) {
    let button = $('#save_button');
    button.button('loading');

    this.setProperties({
      'model.clientErrors': [],
      'model.serverErrors': [],
    });

    this.model.validate().then(function() {
      if(this.get('model.validations.isValid') === false) {
        this.set('model.clientErrors', this.get('model.validations.errors'));
        this.scrollToErrors();
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
            this.set('model.serverErrors', [{ message: 'Unexpected error' }]);
          }

          this.scrollToErrors();
        }.bind(this));
      }
    }.bind(this));
  },

  destroyRecord(options) {
    bootbox.confirm(options.prompt, function(result) {
      if(result) {
        this.model.destroyRecord().then(function() {
          PNotify.success({
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
