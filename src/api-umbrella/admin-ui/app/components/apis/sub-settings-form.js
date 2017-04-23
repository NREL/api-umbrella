import Ember from 'ember';
import BufferedProxy from 'ember-buffered-proxy/proxy';
import SubSettings from 'api-umbrella-admin-ui/models/api/sub-settings';

export default Ember.Component.extend({
  openModal: false,
  httpMethodOptions: [
    { id: 'any', name: 'Any' },
    { id: 'GET', name: 'GET' },
    { id: 'POST', name: 'POST' },
    { id: 'PUT', name: 'PUT' },
    { id: 'DELETE', name: 'DELETE' },
    { id: 'HEAD', name: 'HEAD' },
    { id: 'TRACE', name: 'TRACE' },
    { id: 'OPTIONS', name: 'OPTIONS' },
    { id: 'CONNECT', name: 'CONNECT' },
    { id: 'PATCH', name: 'PATCH' },
  ],

  modalTitle: Ember.computed('model', function() {
    if(this.get('model.isNew')) {
      return 'Add Sub-URL Request Settings';
    } else {
      return 'Edit Sub-URL Request Settings';
    }
  }),

  bufferedModel: Ember.computed('model', function() {
    let owner = Ember.getOwner(this).ownerInjection();
    return BufferedProxy.extend(SubSettings.validationClass).create(owner, { content: this.get('model') });
  }),

  actions: {
    submit() {
      this.get('bufferedModel').applyChanges();
      if(this.get('model.isNew')) {
        this.get('collection').pushObject(this.get('model'));
      }

      this.set('openModal', false);
    },

    closed() {
      this.get('bufferedModel').discardChanges();
    },
  },
});
