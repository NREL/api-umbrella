import { sprintf, t } from 'api-umbrella-admin-ui/utils/i18n';

import Component from '@ember/component';
// eslint-disable-next-line ember/no-mixins
import Save from 'api-umbrella-admin-ui/mixins/save';
import { computed } from '@ember/object';
import escape from 'lodash-es/escape';
import { inject } from '@ember/service';
import usernameLabel from 'api-umbrella-admin-ui/utils/username-label';

export default Component.extend(Save, {
  session: inject(),

  currentAdmin: computed.reads('session.data.authenticated.admin'),

  usernameLabel: computed(usernameLabel),

  actions: {
    submit() {
      this.saveRecord({
        transitionToRoute: 'admins',
        message: sprintf(t('Successfully saved the admin "%s"'), escape(this.model.username)),
      });
    },

    delete() {
      this.destroyRecord({
        prompt: sprintf(t('Are you sure you want to delete the admin "%s"?'), escape(this.model.username)),
        transitionToRoute: 'admins',
        message: sprintf(t('Successfully deleted the admin "%s"'), escape(this.model.username)),
      });
    },
  },
});
