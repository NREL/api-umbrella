Admin.AdminScopesFormController = Ember.ObjectController.extend({
  actions: {
    submit: function() {
      var button = $('#save_button');
      button.button('loading');

      this.get('model').save().then(_.bind(function() {
        button.button('reset');
        $.pnotify({
          type: 'success',
          title: 'Saved',
          text: 'Successfully saved the admin scope \'' + this.get('model').get('username') + '\'',
        });

        this.transitionTo('admin_scopes');
      }, this), function(response) {
        var message = '<h3>Error</h3>';
        try {
          var errors = response.responseJSON.errors;
          for(var prop in errors) {
            message += prop + ': ' + errors[prop].join(', ') + '<br>';
          }
        } catch(e) {
          message = 'An unexpected error occurred: ' + response.responseText;
        }

        button.button('reset');
        bootbox.alert(message);
      });
    },
  },
});

Admin.AdminScopesEditController = Admin.AdminScopesFormController.extend();
Admin.AdminScopesNewController = Admin.AdminScopesFormController.extend();
