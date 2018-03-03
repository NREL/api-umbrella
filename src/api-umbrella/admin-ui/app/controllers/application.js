import Ember from 'ember';

export default Ember.Controller.extend({
  session: Ember.inject.service('session'),

  isLoading: null,

  currentAdmin: Ember.computed(function() {
    return this.get('session.data.authenticated.admin');
  }),

  actions: {
    logout() {
      this.get('session').invalidate();
    },
  },
});
