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
      this.saveRecord({
        transitionToRoute: 'admin_groups',
        message: 'Successfully saved the admin group "' + _.escape(this.get('model.name')) + '"',
      });
    },

    delete() {
      this.destroyRecord({
        prompt: 'Are you sure you want to delete the admin group "' + _.escape(this.get('model.name')) + '"?',
        transitionToRoute: 'admin_groups',
        message: 'Successfully deleted the admin group "' + _.escape(this.get('model.name')) + '"',
      });
    },
  },
});
