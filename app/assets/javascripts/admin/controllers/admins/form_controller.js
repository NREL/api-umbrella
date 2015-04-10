Admin.AdminsFormController = Ember.ObjectController.extend(Admin.Save, {
  groupOptions: function() {
    return Admin.AdminGroup.find();
  }.property(),

  currentAdmin: function() {
    return currentAdmin;
  }.property(),

  actions: {
    submit: function() {
      this.save({
        transitionToRoute: 'admins',
        message: 'Successfully saved the admin "' + _.escape(this.get('model.username')) + '"',
      });
    },
  },
});

Admin.AdminsEditController = Admin.AdminsFormController.extend();
Admin.AdminsNewController = Admin.AdminsFormController.extend();
