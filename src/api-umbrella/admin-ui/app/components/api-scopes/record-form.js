import Component from '@ember/component';
import Save from 'api-umbrella-admin-ui/mixins/save';
import escape from 'lodash-es/escape';

export default Component.extend(Save, {
  actions: {
    submit() {
      this.saveRecord({
        transitionToRoute: 'api_scopes',
        message: 'Successfully saved the API scope "' + escape(this.model.name) + '"',
      });
    },

    delete() {
      this.destroyRecord({
        prompt: 'Are you sure you want to delete the API scope "' + escape(this.model.name) + '"?',
        transitionToRoute: 'api_scopes',
        message: 'Successfully deleted the API scope "' + escape(this.model.name) + '"',
      });
    },
  },
});
