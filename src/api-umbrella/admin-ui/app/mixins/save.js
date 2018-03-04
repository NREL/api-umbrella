import $ from 'jquery';
import Mixin from '@ember/object/mixin'
import PNotify from 'npm:pnotify';
import { inject } from '@ember/service';

export default Mixin.create({
  router: inject(),

  scrollToErrors() {
    $('#save_button').button('reset');
    $.scrollTo('#error_messages', { offset: -60, duration: 200 });
  },

  afterSaveComplete(options, button) {
    button.button('reset');
    new PNotify({
      type: 'success',
      title: 'Saved',
      text: (_.isFunction(options.message)) ? options.message(this.get('model')) : options.message,
    });

    this.get('router').transitionTo(options.transitionToRoute);
  },

  saveRecord(options) {
    let button = $('#save_button');
    button.button('loading');

    this.setProperties({
      'model.clientErrors': [],
      'model.serverErrors': [],
    });

    this.get('model').validate().then(function() {
      if(this.get('model.validations.isValid') === false) {
        this.set('model.clientErrors', this.get('model.validations.errors'));
        this.scrollToErrors();
      } else {
        this.get('model').save().then(function() {
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
        this.get('model').destroyRecord().then(function() {
          new PNotify({
            type: 'success',
            title: 'Deleted',
            text: (_.isFunction(options.message)) ? options.message(this.get('model')) : options.message,
          });

          this.get('router').transitionTo(options.transitionToRoute);
        }.bind(this), function(response) {
          bootbox.alert('Unexpected error deleting record: ' + response.responseText);
        });
      }
    }.bind(this));
  },
});
