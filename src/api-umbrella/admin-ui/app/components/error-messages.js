import Component from '@ember/component';
import I18n from 'i18n-js';
import { computed } from '@ember/object';
import each from 'lodash-es/each';
import inflection from 'inflection';
import isArray from 'lodash-es/isArray';
import marked from 'marked';

export default Component.extend({
  messages: computed('model.{constructor.modelName,clientErrors,serverErrors}', function() {
    let errors = [];
    let modelI18nRoot = 'mongoid.attributes.' + this.model.constructor.modelName.replace('-', '_');

    let clientErrors = this.model.clientErrors;
    if(clientErrors) {
      if(isArray(clientErrors)) {
        each(clientErrors, function(clientError) {
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

    let serverErrors = this.model.serverErrors;
    if(serverErrors) {
      if(isArray(serverErrors)) {
        each(serverErrors, function(serverError) {
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
    each(errors, function(error) {
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

  hasErrors: computed.gt('messages.length', 0),
});
