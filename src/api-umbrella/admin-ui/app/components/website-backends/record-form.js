import Ember from 'ember';
import Save from 'api-umbrella-admin-ui/mixins/save';

export default Ember.Component.extend(Save, {
  backendProtocolOptions: [
    { id: 'http', name: 'http' },
    { id: 'https', name: 'https' },
  ],

  changeDefaultPort: function() {
    let protocol = this.get('model.backendProtocol');
    let port = parseInt(this.get('model.serverPort'), 10);
    if(protocol === 'https') {
      if(!port || port === 80) {
        this.set('model.serverPort', 443);
      }
    } else {
      if(!port || port === 443) {
        this.set('model.serverPort', 80);
      }
    }
  }.observes('model.backendProtocol'),

  actions: {
    submit() {
      this.saveRecord({
        transitionToRoute: 'website_backends',
        message: 'Successfully saved the "' + _.escape(this.get('model.frontendHost')) + '" website backend<br><strong>Note:</strong> Your changes are not yet live. <a href="/admin/#/config/publish">Publish Changes</a> to send your updates live.',
      });
    },

    delete() {
      this.destroyRecord({
        prompt: 'Are you sure you want to delete the website backend "' + _.escape(this.get('model.frontendHost')) + '"?',
        transitionToRoute: 'website_backends',
        message: 'Successfully deleted the "' + _.escape(this.get('model.frontendHost')) + '" website backend<br><strong>Note:</strong> Your changes are not yet live. <a href="/admin/#/config/publish">Publish Changes</a> to send your updates live.',
      });
    },
  },
});
