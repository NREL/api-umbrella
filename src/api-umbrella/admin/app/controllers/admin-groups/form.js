import Ember from 'ember';

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
        message: 'Successfully saved the admin group "' + _.escape(this.get('model.name')) + '"',
      });
    },

    delete: function() {
      bootbox.confirm('Are you sure you want to delete this admin group?', _.bind(function(result) {
        if(result) {
          this.get('model').deleteRecord();
          this.transitionToRoute('admin_groups');
        }
      }, this));
    },
  },
});
Admin.AdminGroupsEditController = Admin.AdminGroupsFormController.extend();
Admin.AdminGroupsNewController = Admin.AdminGroupsFormController.extend();

export default undefined;
