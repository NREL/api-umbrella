import Controller from '@ember/controller';
import { computed } from '@ember/object';
import { inject } from '@ember/service';

export default Controller.extend({
  session: inject('session'),

  isLoading: null,

  currentAdmin: computed.reads('session.data.authenticated.admin'),

  actions: {
    logout() {
      this.session.invalidate();
    },
  },
});
