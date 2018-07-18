import Controller from '@ember/controller';
import { computed } from '@ember/object';
import { inject } from '@ember/service';

export default Controller.extend({
  session: inject('session'),

  isLoading: null,

  currentAdmin: computed(function() {
    return this.get('session.data.authenticated.admin');
  }),

  actions: {
    logout() {
      this.get('session').invalidate();
    },
  },
});
