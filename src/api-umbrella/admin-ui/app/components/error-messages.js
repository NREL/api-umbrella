import Ember from 'ember';

export default Ember.Component.extend({
  messages: Ember.computed('model.clientErrors', 'model.serverErrors', function() {
    let errors = [];

    let clientErrors = this.get('model.clientErrors');
    if(clientErrors) {
      if(_.isArray(clientErrors)) {
        _.each(clientErrors, function(clientError) {
          let message = clientError.get('message');
          if(message) {
            errors.push({
              attribute: clientError.get('attribute'),
              message: message,
            });
          } else {
            errors.push({ message: 'Unexpected error' });
          }
        });
      } else {
        errors.push({ message: 'Unexpected error' });
      }
    }

    let serverErrors = this.get('model.serverErrors');
    if(serverErrors) {
      if(_.isArray(serverErrors)) {
        _.each(serverErrors, function(serverError) {
          let message = serverError.full_message || serverError.message;
          if(!message && serverError.title) {
            message = serverError.title;
            if(serverError.status) {
              message += ' (Status: ' + serverError.status + ')';
            }
          }

          if(message) {
            errors.push({
              attribute: serverError.field,
              message: message,
            });
          } else {
            errors.push({ message: 'Unexpected error' });
          }
        });
      } else {
        errors.push({ message: 'Unexpected error' });
      }
    }

    let messages = [];
    _.each(errors, function(error) {
      let message = error.message || 'Unexpected error';
      messages.push(marked(message));
    });

    return messages;
  }),

  hasErrors: Ember.computed('messages', function() {
    return (this.get('messages').length > 0);
  }),
});
