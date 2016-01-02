import Ember from 'ember';

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

    delete: function() {
      bootbox.confirm('Are you sure you want to delete this admin?', _.bind(function(result) {
        if(result) {
          this.get('model').deleteRecord();
          this.transitionToRoute('admins');
        }
      }, this));
    },
  },
});
Admin.AdminsEditController = Admin.AdminsFormController.extend();
Admin.AdminsNewController = Admin.AdminsFormController.extend();

export default undefined;
