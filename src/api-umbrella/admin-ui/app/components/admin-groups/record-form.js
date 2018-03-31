import Component from '@ember/component';
import Save from 'api-umbrella-admin-ui/mixins/save';

export default Component.extend(Save, {
  actions: {
    submit() {
      this.saveRecord({
        transitionToRoute: 'admin_groups',
        message: 'Successfully saved the admin group "' + _.escape(this.get('model.name')) + '"',
      });
    },

    delete() {
      this.destroyRecord({
        prompt: 'Are you sure you want to delete the admin group "' + _.escape(this.get('model.name')) + '"?',
        transitionToRoute: 'admin_groups',
        message: 'Successfully deleted the admin group "' + _.escape(this.get('model.name')) + '"',
      });
    },
  },
});
