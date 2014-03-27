Admin.ApiUsersFormController = Ember.ObjectController.extend({
  throttleByIpOptions: [
    { id: false, name: "Rate limit by API key" },
    { id: true, name: "Rate limit by IP address" },
  ],

  enabledOptions: [
    { id: true, name: "Enabled" },
    { id: false, name: "Disabled" },
  ],

  actions: {
    submit: function() {
      var button = $('#save_button');
      button.button('loading');

      this.get('model').save().then(_.bind(function() {;
        button.button('reset');
        $.pnotify({
          type: "success",
          title: "Saved",
          text: "Successfully saved the user '" + this.get('model').get('email') + "'",
        });

        this.transitionTo('api_users');
      }, this), function(response) {
        var message = "<h3>Error</h3>";
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
