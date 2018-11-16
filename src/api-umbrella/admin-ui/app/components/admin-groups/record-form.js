import Component from '@ember/component';
import Save from 'api-umbrella-admin-ui/mixins/save';
import escape from 'lodash-es/escape';

export default Component.extend(Save, {
  actions: {
    submit() {
      this.saveRecord({
        transitionToRoute: 'admin_groups',
        message: 'Successfully saved the admin group "' + escape(this.get('model.name')) + '"',
      });
    },

    delete() {
      this.destroyRecord({
        prompt: 'Are you sure you want to delete the admin group "' + escape(this.get('model.name')) + '"?',
        transitionToRoute: 'admin_groups',
        message: 'Successfully deleted the admin group "' + escape(this.get('model.name')) + '"',
      });
    },
  },
});
