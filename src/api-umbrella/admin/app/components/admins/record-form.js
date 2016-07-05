import Ember from 'ember';
import Save from 'api-umbrella-admin/mixins/save';

export default Ember.Component.extend(Save, {
  session: Ember.inject.service(),
  store: Ember.inject.service(),

  groupOptions: Ember.computed(function() {
    return this.get('store').findAll('admin-group');
  }),

  currentAdmin: Ember.computed(function() {
    return this.get('session.data.authenticated.admin');
  }),

  actions: {
    submit() {
      this.save({
        transitionToRoute: 'admins',
        message: 'Successfully saved the admin "' + _.escape(this.get('model.username')) + '"',
      });
    },

    delete() {
      bootbox.confirm('Are you sure you want to delete this admin?', _.bind(function(result) {
        if(result) {
          this.get('model').deleteRecord();
          this.transitionToRoute('admins');
        }
      }, this));
    },
  },
});
