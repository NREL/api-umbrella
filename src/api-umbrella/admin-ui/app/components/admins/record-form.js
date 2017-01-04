import Ember from 'ember';
import Save from 'api-umbrella-admin-ui/mixins/save';

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
      this.saveRecord({
        // If updating the current admin user account, then trigger an
        // authentication check after the updating the user. This is because
        // Devise requires the user to log back in if they've changed their
        // password.
        afterSave: (callback) => {
          if(this.get('model.id') !== this.get('currentAdmin.id')) {
            callback();
          } else {
            this.get('session').authenticate('authenticator:devise-server-side').then(() => {
              callback();
            }, (error) => {
              if(error !== 'unexpected_error') {
                window.location.href = '/admin/login';
              } else {
                callback();
              }
            });
          }
        },
        transitionToRoute: 'admins',
        message: 'Successfully saved the admin "' + _.escape(this.get('model.username')) + '"',
      });
    },

    delete() {
      this.destroyRecord({
        prompt: 'Are you sure you want to delete the admin "' + _.escape(this.get('model.username')) + '"?',
        transitionToRoute: 'admins',
        message: 'Successfully deleted the admin "' + _.escape(this.get('model.username')) + '"',
      });
    },
  },
});
