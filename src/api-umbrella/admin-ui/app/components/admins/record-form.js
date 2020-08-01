import Component from '@ember/component';
// eslint-disable-next-line ember/no-mixins
import Save from 'api-umbrella-admin-ui/mixins/save';
import { computed } from '@ember/object';
import escape from 'lodash-es/escape';
import { inject } from '@ember/service';

export default Component.extend(Save, {
  session: inject(),

  currentAdmin: computed.reads('session.data.authenticated.admin'),

  actions: {
    submit() {
      this.saveRecord({
        transitionToRoute: 'admins',
        message: 'Successfully saved the admin "' + escape(this.model.username) + '"',
      });
    },

    delete() {
      this.destroyRecord({
        prompt: 'Are you sure you want to delete the admin "' + escape(this.model.username) + '"?',
        transitionToRoute: 'admins',
        message: 'Successfully deleted the admin "' + escape(this.model.username) + '"',
      });
    },
  },
});
