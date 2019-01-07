import { sprintf, t } from 'api-umbrella-admin-ui/utils/i18n';

import Component from '@ember/component';
import Save from 'api-umbrella-admin-ui/mixins/save';
import { computed } from '@ember/object';
import escape from 'lodash-es/escape';
import { inject } from '@ember/service';
import usernameLabel from 'api-umbrella-admin-ui/utils/username-label';

export default Component.extend(Save, {
  session: inject(),

  currentAdmin: computed(function() {
    return this.get('session.data.authenticated.admin');
  }),

  usernameLabel: computed(usernameLabel),

  actions: {
    submit() {
      this.saveRecord({
        transitionToRoute: 'admins',
        message: sprintf(t('Successfully saved the admin "%s"'), escape(this.get('model.username'))),
      });
    },

    delete() {
      this.destroyRecord({
        prompt: sprintf(t('Are you sure you want to delete the admin "%s"?'), escape(this.get('model.username'))),
        transitionToRoute: 'admins',
        message: sprintf(t('Successfully deleted the admin "%s"'), escape(this.get('model.username'))),
      });
    },
  },
});
