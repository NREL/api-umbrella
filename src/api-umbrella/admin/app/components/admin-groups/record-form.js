import Ember from 'ember';
import Save from 'api-umbrella-admin/mixins/save';

export default Ember.Component.extend(Save, {
  store: Ember.inject.service(),

  apiScopeOptions: Ember.computed(function() {
    return this.get('store').findAll('api-scope');
  }),

  permissionOptions: Ember.computed(function() {
    return this.get('store').findAll('admin-permission');
  }),

  actions: {
    submit() {
      this.save({
        transitionToRoute: 'admin_groups',
        message: 'Successfully saved the admin group "' + _.escape(this.get('model.name')) + '"',
      });
    },

    delete() {
      bootbox.confirm('Are you sure you want to delete this admin group?', _.bind(function(result) {
        if(result) {
          this.get('model').deleteRecord();
          this.transitionToRoute('admin_groups');
        }
      }, this));
    },
  },
});
