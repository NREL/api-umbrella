Admin.AdminGroupsFormController = Ember.ObjectController.extend({
  scopeOptions: function() {
    return Admin.AdminScope.find();
  }.property(),

  accessOptions: [
    { id: "analytics", name: "Analytics" },
    { id: "user_view", name: "API Users - View" },
    { id: "user_manage", name: "API Users - Manage" },
    { id: "admin_manage", name: "Admin Accounts - View & Manage" },
    { id: "backend_manage", name: "API Backend Configuration - View & Manage" },
    { id: "backend_publish", name: "API Backend Configuration - Publish" },
  ],

  actions: {
    submit: function() {
      var button = $('#save_button');
      button.button('loading');

      this.get('model').save().then(_.bind(function() {
        button.button('reset');
        $.pnotify({
          type: "success",
          title: "Saved",
          text: "Successfully saved the admin group '" + this.get('model').get('username') + "'",
        });

        this.transitionTo('admin_groups');
      }, this), function(response) {
        var message = "<h3>Error</h3>";
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

Admin.AdminGroupsEditController = Admin.AdminGroupsFormController.extend();
Admin.AdminGroupsNewController = Admin.AdminGroupsFormController.extend();
