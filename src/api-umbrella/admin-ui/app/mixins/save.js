import Ember from 'ember';

export default Ember.Mixin.create({
  routing: Ember.inject.service('-routing'),

  scrollToErrors() {
    $('#save_button').button('reset');
    $.scrollTo('#error_messages', { offset: -60, duration: 200 });
  },

  saveRecord(options) {
    let button = $('#save_button');
    button.button('loading');

    this.get('model').validate().then(function() {
      if(this.get('model.validations.isValid') === false) {
        this.set('model.clientErrors', this.get('model.validations.errors'));
        this.scrollToErrors();
      } else {
        this.get('model').save().then(function() {
          button.button('reset');
          new PNotify({
            type: 'success',
            title: 'Saved',
            text: (_.isFunction(options.message)) ? options.message(this.get('model')) : options.message,
          });

          this.get('routing').transitionTo(options.transitionToRoute);
        }.bind(this), function(response) {
          // Set the errors from the server response on a "serverErrors" property
          // for the error-messages component display.
          try {
            this.set('model.serverErrors', response.responseJSON.errors);
          } catch(e) {
            this.set('model.serverErrors', response.responseText);
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

          this.get('routing').transitionTo(options.transitionToRoute);
        }.bind(this), function(response) {
          bootbox.alert('Unexpected error deleting record: ' + response.responseText);
        });
      }
    }.bind(this));
  },
});
