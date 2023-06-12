// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { computed } from '@ember/object';
import { gt } from '@ember/object/computed';
import { tagName } from '@ember-decorators/component';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import classic from 'ember-classic-decorator';
import each from 'lodash-es/each';
import isArray from 'lodash-es/isArray';
import { marked } from 'marked';

marked.use({
  gfm: true,
  breaks: true,
  mangle: false,
  headerIds: false,
});

@classic
@tagName("")
export default class ErrorMessages extends Component {
  @computed('model.{constructor.modelName,clientErrors,serverErrors}')
  get messages() {
    let errors = [];

    let clientErrors = this.model.clientErrors;
    if(clientErrors) {
      if(isArray(clientErrors)) {
        each(clientErrors, function(clientError) {
          let message = clientError.get('message');
          if(message) {
            errors.push({
              attribute: clientError.get('attribute'),
              message: message,
              // Assume the client-side validators are setup with a
              // "description" so they are suitable for full sentence display.
              fullMessage: message,
            });
          } else {
            errors.push({ message: t('Unexpected error') });
          }
        });
      } else {
        errors.push({ message: t('Unexpected error') });
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
            errors.push({ message: t('Unexpected error') });
          }
        });
      } else {
        errors.push({ message: t('Unexpected error') });
      }
    }

    let messages = [];
    each(errors, function(error) {
      let message = '';
      if(error.fullMessage) {
        message += error.fullMessage;
      } else {
        // If a full sentence error message isn't available, then fallback to
        // showing the attribute name, plus the error message. While not ideal,
        // since the attribute name won't be localized and may not be
        // super-readable for humans, it's at least some context.
        if(error.attribute && error.attribute !== 'base') {
          message += error.attribute + ': ';
        }
        message += error.message || t('Unexpected error');
      }

      messages.push(marked(message));
    });

    return messages;
  }

  @gt('messages.length', 0)
  hasErrors;
}
