Admin.ApiUsersFormController = Ember.ObjectController.extend({
  throttleByIpOptions: [
    { id: false, name: 'Rate limit by API key' },
    { id: true, name: 'Rate limit by IP address' },
  ],

  enabledOptions: [
    { id: true, name: 'Enabled' },
    { id: false, name: 'Disabled' },
  ],

  roleOptions: function() {
    return Admin.ApiUserRole.find();
    // Don't cache this property, so we can rely on refreshing the underlying
    // model to refresh the options.
  }.property().cacheable(false),

  actions: {
    submit: function() {
      var button = $('#save_button');
      button.button('loading');

      // Force dirty to force save (ember-model's dirty tracking fails to
      // account for changes in nested, non-association objects:
      // http://git.io/sbS1mg This is mainly for ApiSettings's errorTemplates
      // and errorDataYamlStrings, but we've seen enough funkiness elsewhere,
      // it seems worth disabling for now).
      this.set('model.isDirty', true);

      this.get('model').save().then(_.bind(function() {
        button.button('reset');
        new PNotify({
          type: 'success',
          title: 'Saved',
          text: 'Successfully saved the user \'' + this.get('model').get('email') + '\'',
        });

        this.transitionToRoute('api_users');
      }, this), function(response) {
        var message = '<h3>Error</h3>';
        try {
          var errors = response.responseJSON.errors;
          _.each(errors, function(error) {
            message += error.field + ': ' + error.message + '<br>';
          });
        } catch(e) {
          message = 'An unexpected error occurred: ' + response.responseText;
        }

        button.button('reset');
        bootbox.alert(message);
      });
    },
  },
});

Admin.ApiUsersEditController = Admin.ApiUsersFormController.extend();
Admin.ApiUsersNewController = Admin.ApiUsersFormController.extend();
