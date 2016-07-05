import Ember from 'ember';

export default Ember.Component.extend({
  messages: Ember.computed('model.clientErrors', 'model.serverErrors', function() {
    let messages = [];

    let errors = {};
    let clientErrors = this.get('model.clientErrors');
    if(clientErrors) {
      if(_.isArray(clientErrors)) {
        _.each(clientErrors, function(clientError) {
          let field = 'base';
          let message = clientError;
          if(_.isObject(clientError)) {
            if(clientError.get('attribute')) {
              field = clientError.get('attribute');
            }

            message = clientError.get('message');
          }

          if(!errors[field]) {
            errors[field] = [];
          }

          errors[field].push(message);
        });
      } else {
        errors = _.merge(errors, clientErrors);
      }
    }

    let serverErrors = this.get('model.serverErrors');
    if(serverErrors) {
      if(_.isString(serverErrors)) {
        messages.push(serverErrors);
      } else if(_.isArray(serverErrors)) {
        _.each(serverErrors, function(serverError) {
          let field = 'base';
          let message = serverError;
          if(_.isObject(serverError)) {
            if(serverError.field) {
              field = serverError.field;
            }

            message = serverError.message;
          }

          if(!errors[field]) {
            errors[field] = [];
          }

          errors[field].push(message);
        });
      } else {
        errors = _.merge(errors, serverErrors);
      }
    }

    _.forOwn(errors, function(attrErrors, attr) {
      _.each(attrErrors, function(attrError) {
        let message = '';
        if(attr !== 'base') {
          message += inflection.titleize(inflection.underscore(attr)) + ': ';
        }
        message += attrError;

        messages.push(marked(message));
      });
    });

    return messages;
  }),

  hasErrors: Ember.computed('messages', function() {
    return (this.get('messages').length > 0);
  }),
});
