import Component from '@ember/component';
import Save from 'api-umbrella-admin-ui/mixins/save';
import escape from 'lodash-es/escape';
// eslint-disable-next-line ember/no-observers
import { observer } from '@ember/object';

export default Component.extend(Save, {
  init() {
    this._super(...arguments);

    this.backendProtocolOptions = [
      { id: 'http', name: 'http' },
      { id: 'https', name: 'https' },
    ];
  },

  // eslint-disable-next-line ember/no-observers
  changeDefaultPort: observer('model.backendProtocol', function() {
    let protocol = this.model.backendProtocol;
    let port = parseInt(this.model.serverPort, 10);
    if(protocol === 'https') {
      if(!port || port === 80) {
        this.set('model.serverPort', 443);
      }
    } else {
      if(!port || port === 443) {
        this.set('model.serverPort', 80);
      }
    }
  }),

  actions: {
    submit() {
      this.saveRecord({
        transitionToRoute: 'website_backends',
        message: 'Successfully saved the "' + escape(this.model.frontendHost) + '" website backend<br><strong>Note:</strong> Your changes are not yet live. <a href="/admin/#/config/publish">Publish Changes</a> to send your updates live.',
      });
    },

    delete() {
      this.destroyRecord({
        prompt: 'Are you sure you want to delete the website backend "' + escape(this.model.frontendHost) + '"?',
        transitionToRoute: 'website_backends',
        message: 'Successfully deleted the "' + escape(this.model.frontendHost) + '" website backend<br><strong>Note:</strong> Your changes are not yet live. <a href="/admin/#/config/publish">Publish Changes</a> to send your updates live.',
      });
    },
  },
});
