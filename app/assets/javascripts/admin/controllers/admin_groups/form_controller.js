Admin.AdminGroupsFormController = Ember.ObjectController.extend(Admin.Save, {
  apiScopeOptions: function() {
    return Admin.ApiScope.find();
  }.property(),

  permissionOptions: function() {
    return Admin.AdminPermission.find();
  }.property(),

  actions: {
    submit: function() {
      this.save({
        transitionToRoute: 'admin_groups',
        message: 'Successfully saved the admin group "' + this.get('model.name') + '"',
      });
    },
  },
});

Admin.AdminGroupsEditController = Admin.AdminGroupsFormController.extend();
Admin.AdminGroupsNewController = Admin.AdminGroupsFormController.extend();
