// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { computed } from '@ember/object';
import { gt } from '@ember/object/computed';
import { tagName } from '@ember-decorators/component';
import classic from 'ember-classic-decorator';
import I18n from 'i18n-js';
import { titleize, underscore } from 'inflection';
import each from 'lodash-es/each';
import isArray from 'lodash-es/isArray';
import marked from 'marked';

@classic
@tagName("")
export default class ErrorMessages extends Component {
  @computed('model.{constructor.modelName,clientErrors,serverErrors}')
  get messages() {
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
        let attributeTitle = I18n.t(modelI18nRoot + '.' + underscore(error.attribute), { defaultValue: false });
        if(attributeTitle === false) {
          attributeTitle = titleize(underscore(error.attribute));
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
  }

  @gt('messages.length', 0)
  hasErrors;
}
