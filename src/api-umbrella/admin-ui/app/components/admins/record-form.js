import Ember from 'ember';
import Save from 'api-umbrella-admin-ui/mixins/save';

export default Ember.Component.extend(Save, {
  session: Ember.inject.service(),

  currentAdmin: Ember.computed(function() {
    return this.get('session.data.authenticated.admin');
  }),

  actions: {
    submit() {
      this.saveRecord({
        transitionToRoute: 'admins',
        message: 'Successfully saved the admin "' + _.escape(this.get('model.username')) + '"',
      });
    },

    delete() {
      this.destroyRecord({
        prompt: 'Are you sure you want to delete the admin "' + _.escape(this.get('model.name')) + '"?',
        transitionToRoute: 'admins',
        message: 'Successfully deleted the admin "' + _.escape(this.get('model.name')) + '"',
      });
    },
  },
});
