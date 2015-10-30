Admin.ApiUsersFormController = Ember.ObjectController.extend(Admin.Save, {
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
      this.save({
        transitionToRoute: 'api_users',
        message: function(model) {
          var message = 'Successfully saved the user "' + _.escape(model.get('email')) + '"';
          if(model.get('apiKey')) {
            message += '<br>API Key: <code>' + _.escape(model.get('apiKey')) + '</code>';
          }

          return message;
        },
      });
    },
  },
});

Admin.ApiUsersEditController = Admin.ApiUsersFormController.extend();
Admin.ApiUsersNewController = Admin.ApiUsersFormController.extend();
