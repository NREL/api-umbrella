import Component from '@ember/component';
import I18n from 'npm:i18n-js';
import { computed } from '@ember/object';

export default Component.extend({
  messages: computed('model.{clientErrors,serverErrors}', function() {
    let errors = [];
    let modelI18nRoot = 'mongoid.attributes.' + this.get('model.constructor.modelName').replace('-', '_');

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
          let message = serverError.message;
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
              fullMessage: serverError.full_message,
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
      let message = '';
      if(error.fullMessage) {
        message += error.fullMessage;
      } else if(error.attribute && error.attribute !== 'base') {
        let attributeTitle = I18n.t(modelI18nRoot + '.' + inflection.underscore(error.attribute), { defaultValue: false });
        if(attributeTitle === false) {
          attributeTitle = inflection.titleize(inflection.underscore(error.attribute));
        }

        message += attributeTitle + ': ';
        message += error.message || 'Unexpected error';
      } else {
        if(error.message) {
          message += error.message.charAt(0).toUpperCase() + error.message.slice(1);
        } else {
          message += 'Unexpected error';
        }
      }

      messages.push(marked(message));
    });

    return messages;
  }),

  hasErrors: computed('messages', function() {
    return (this.get('messages').length > 0);
  }),
});
