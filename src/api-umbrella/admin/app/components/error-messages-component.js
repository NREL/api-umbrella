Admin.ErrorMessagesComponent = Ember.Component.extend({
  messages: function() {
    var messages = [];

    var errors = _.extend({}, this.get('model.clientErrors'));

    var serverErrors = this.get('model.serverErrors');
    if(serverErrors) {
      if(_.isString(serverErrors)) {
        messages.push(serverErrors);
      } else if(_.isArray(serverErrors)) {
        _.each(serverErrors, function(serverError) {
          var field = 'base';
          var message = serverError;
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
        var message = '';
        if(attr !== 'base') {
          message += inflection.titleize(inflection.underscore(attr)) + ': ';
        }
        message += attrError;

        messages.push(marked(message));
      });
    });

    return messages;
  }.property('model.clientErrors', 'model.serverErrors'),
});
