import Ember from 'ember';
import Save from 'api-umbrella-admin-ui/mixins/save';
import usernameLabel from 'api-umbrella-admin-ui/utils/username-label';
import { sprintf, t } from 'api-umbrella-admin-ui/utils/i18n';

export default Ember.Component.extend(Save, {
  session: Ember.inject.service(),

  currentAdmin: Ember.computed(function() {
    return this.get('session.data.authenticated.admin');
  }),

  usernameLabel: Ember.computed(usernameLabel),

  actions: {
    submit() {
      this.saveRecord({
        transitionToRoute: 'admins',
        message: sprintf(t('Successfully saved the admin "%s"'), _.escape(this.get('model.username'))),
      });
    },

    delete() {
      this.destroyRecord({
        prompt: sprintf(t('Are you sure you want to delete the admin "%s"?'), _.escape(this.get('model.username'))),
        transitionToRoute: 'admins',
        message: sprintf(t('Successfully deleted the admin "%s"'), _.escape(this.get('model.username'))),
      });
    },
  },
});
