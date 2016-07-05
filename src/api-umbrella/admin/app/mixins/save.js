import Ember from 'ember';

export default Ember.Mixin.create({
  router: Ember.inject.service('router'),

  scrollToErrors() {
    $('#save_button').button('reset');
    $.scrollTo('#error_messages', { offset: -60, duration: 200 });
  },

  save(options) {
    let button = $('#save_button');
    button.button('loading');

    this.get('model').validate().then(function() {
      if(this.get('model.validations.isValid') === false) {
        this.set('model.clientErrors', this.get('model.validations.errors'));
        this.scrollToErrors();
      } else {
        this.get('model').save().then(_.bind(function() {
          button.button('reset');
          new PNotify({
            type: 'success',
            title: 'Saved',
            text: (_.isFunction(options.message)) ? options.message(this.get('model')) : options.message,
          });

          this.sendAction('action', options.transitionToRoute);
        }, this), _.bind(function(response) {
          // Set the errors from the server response on a "serverErrors" property
          // for the error-messages component display.
          try {
            this.set('model.serverErrors', response.responseJSON.errors);
          } catch(e) {
            this.set('model.serverErrors', response.responseText);
          }

          this.scrollToErrors();
        }, this));
      }
    }.bind(this));
  },
});
